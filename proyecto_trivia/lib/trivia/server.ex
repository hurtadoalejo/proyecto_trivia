defmodule Trivia.Server do
  use GenServer
  alias Trivia.Supervisor, as: GameSupervisor

  @archivo_resultados "data/results.csv"

  # ========= API =========

  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(opciones),
    do: GenServer.start_link(__MODULE__, opciones, name: __MODULE__)

  def connect(usuario, clave, pid_cliente),
    do: GenServer.call(__MODULE__, {:connect, usuario, clave, pid_cliente})

  def disconnect(usuario),
    do: GenServer.call(__MODULE__, {:disconnect, usuario})

  def score(usuario),
    do: GenServer.call(__MODULE__, {:score, usuario})

  def global_ranking(tema \\ nil),
    do: GenServer.call(__MODULE__, {:global_ranking, tema})

  def list_games,
    do: GenServer.call(__MODULE__, :list_games)

  def create_game(opciones, usuario),
    do: GenServer.call(__MODULE__, {:create_game, opciones, usuario})

  def join_game(pid_partida, usuario),
    do: GenServer.call(__MODULE__, {:join_game, pid_partida, usuario})

  def start_game(pid_partida),
    do: GenServer.call(__MODULE__, {:start_game, pid_partida, :__desconocido__})

  def start_game(pid_partida, usuario),
    do: GenServer.call(__MODULE__, {:start_game, pid_partida, usuario})

  def answer(pid_partida, usuario, ronda, opcion),
    do: GenServer.call(__MODULE__, {:answer, pid_partida, usuario, ronda, opcion})

  # ========= GenServer =========

  @impl true
  def init(_argumento_inicial) do
    # sesiones: %{usuario => %{pid: pid, monitor: ref, partida: pid_partida | nil}}
    # procesos: %{pid => usuario}
    {:ok, %{sesiones: %{}, procesos: %{}}}
  end

  # ========= Handle Calls =========}

  # Reenvío genérico (se mantiene; útil para :nueva_ronda y :respuesta)
  @impl true
  def handle_cast({:difundir_a_partida, pid_partida, payload}, estado)
      when elem(payload, 0) != :fin_partida do
    Enum.each(estado.sesiones, fn {_usuario, %{pid: pid_cliente, partida: pid_sesion}} ->
      if pid_sesion == pid_partida do
        send(pid_cliente, {:trivia_evento, payload})
      end
    end)

    {:noreply, estado}
  end

  # Reenvío + limpieza cuando termina la partida
  @impl true
  def handle_cast({:difundir_a_partida, pid_partida, {:fin_partida, ganador, puntajes}}, estado) do
    # 1) Reenviar a todos los clientes de esa partida
    Enum.each(estado.sesiones, fn {_usuario, %{pid: pid_cliente, partida: pid_sesion}} ->
      if pid_sesion == pid_partida do
        send(pid_cliente, {:trivia_evento, {:fin_partida, ganador, puntajes}})
      end
    end)

    # 2) Limpiar la marca de partida en sesiones (quedan libres para unirse a otra)
    nuevas_sesiones =
      Enum.reduce(estado.sesiones, %{}, fn {usuario, ses}, acc ->
        ses2 = if ses.partida == pid_partida, do: Map.put(ses, :partida, nil), else: ses
        Map.put(acc, usuario, ses2)
      end)

    {:noreply, %{estado | sesiones: nuevas_sesiones}}
  end

  @impl true
  def handle_call({:connect, usuario, clave, pid_cliente}, _from, estado) do
    if Map.has_key?(estado.sesiones, usuario) do
      {:reply, {:error, :already_connected}, estado}
    else
      case autenticar_o_registrar(usuario, clave) do
        {:ok, status} ->
          {:ok, nuevo_estado} = poner_sesion(estado, usuario, pid_cliente)
          {:reply, {:ok, status}, nuevo_estado}

        {:error, motivo} ->
          {:reply, {:error, motivo}, estado}
      end
    end
  end

  @impl true
  def handle_call({:disconnect, usuario}, _desde, estado) do
    {:reply, :ok, eliminar_sesion(estado, usuario)}
  end

  @impl true
  def handle_call(:list_games, _desde, estado) do
    partidas_vivas =
      GameSupervisor.list_games()
      |> Enum.map(fn {_, pid_partida, _, _} ->
        case GenServer.call(pid_partida, :get_creador) do
          {:ok, creador} -> {pid_partida, creador}
          _ -> {pid_partida, "Desconocido"}
        end
      end)
      |> Enum.filter(fn {pid, _creador} -> is_pid(pid) and Process.alive?(pid) end)

    {:reply, partidas_vivas, estado}
  end

  # === Crear juego (marca creador) ===
  @impl true
  def handle_call({:create_game, opciones, usuario_creador}, _from, estado) do
    case GameSupervisor.start_game(opciones) do
      {:ok, pid_partida} ->
        # 1) Marcar creador en el proceso del juego
        GenServer.cast(pid_partida, {:establecer_creador, usuario_creador})

        # 2) AUTO-UNIR al creador: poner :partida en su sesión
        nuevas_sesiones =
          if Map.has_key?(estado.sesiones, usuario_creador) do
            Map.update!(estado.sesiones, usuario_creador, fn ses -> Map.put(ses, :partida, pid_partida) end)
          else
            estado.sesiones
          end

        # 3) Unir al creador automáticamente a la partida
        # Llamada para unirse a la partida después de ser creada
        {:ok, :unido} = GenServer.call(pid_partida, {:join, usuario_creador})

        {:reply, {:ok, pid_partida}, %{estado | sesiones: nuevas_sesiones}}

      {:error, motivo} ->
        {:reply, {:error, motivo}, estado}
    end
  end

  # === Unirse a juego (una sola sala a la vez) ===
  @impl true
  def handle_call({:join_game, pid_partida, usuario}, _desde, estado) do
    case asegurar_conectado(estado, usuario) do
      :ok ->
        sesion = Map.get(estado.sesiones, usuario)

        cond do
          sesion == nil ->
            {:reply, {:error, :no_conectado}, estado}

          sesion.partida != nil and sesion.partida != pid_partida ->
            {:reply, {:error, :ya_en_otra_partida}, estado}

          true ->
            respuesta = GenServer.call(pid_partida, {:join, usuario})

            case respuesta do
              {:ok, _} ->
                nuevas_sesiones =
                  Map.update!(estado.sesiones, usuario, fn s ->
                    Map.put(s, :partida, pid_partida)
                  end)

                {:reply, respuesta, %{estado | sesiones: nuevas_sesiones}}

              _otro ->
                {:reply, respuesta, estado}
            end
        end

      {:error, motivo} ->
        {:reply, {:error, motivo}, estado}
    end
  end

  # === Iniciar juego (solo creador) ===
  @impl true
  def handle_call({:start_game, pid_partida, usuario_llamador}, _from, estado) do
    respuesta =
      if usuario_llamador == :__desconocido__ do
        # cliente viejo: no sabemos quién es -> Game rechazará por permiso
        GenServer.call(pid_partida, {:start, nil})
      else
        GenServer.call(pid_partida, {:start, usuario_llamador})
      end

    {:reply, respuesta, estado}
  end

  # === Responder ===
  @impl true
  def handle_call({:answer, pid_partida, usuario, ronda, opcion}, _desde, estado) do
    case asegurar_conectado(estado, usuario) do
      :ok ->
        respuesta = GenServer.call(pid_partida, {:answer, usuario, ronda, opcion})
        {:reply, respuesta, estado}

      {:error, motivo} ->
        {:reply, {:error, motivo}, estado}
    end
  end

  # === Puntaje individual ===
  @impl true
  def handle_call({:score, usuario}, _desde, estado) do
    case UserManager.obtener_usuario(usuario) do
      %User{} = datos_usuario ->
        total =
          Enum.reduce(datos_usuario.puntajes, 0, fn {_tema, p}, acc -> p + acc end)

        {:reply, {:ok, total}, estado}

      otro ->
        {:reply, {:error, otro}, estado}
    end
  end

  @impl true
  def handle_call({:global_ranking, nil}, _desde, estado) do
    ranking = UserManager.consultar_puntajes()
    {:reply, ranking, estado}
  end

  @impl true
  def handle_call({:global_ranking, tema}, _desde, estado) do
    ranking = UserManager.consultar_puntajes_tema(tema)
    {:reply, ranking, estado}
  end

  @doc """
  Manejar desconexión de cliente (limpieza automática)
  1) Buscar el usuario asociado al PID muerto
  2) Eliminar índice de PID y sesión del usuario
  3) Si el usuario estaba en una partida, dejarlo ahí (la partida maneja la desconexión)
  4) Si no estaba en ninguna partida, queda libre para unirse a otra
  """
  @impl true
  def handle_info({:DOWN, _monitor, :process, pid_muerto, _razon}, estado) do
    case Map.fetch(estado.procesos, pid_muerto) do
      {:ok, usuario} ->
        nuevo_estado =
          estado
          |> eliminar_indice_pid(pid_muerto)
          |> eliminar_sesion_de_usuario(usuario)

        {:noreply, nuevo_estado}

      :error ->
        {:noreply, estado}
    end
  end

  defp poner_sesion(estado, usuario, pid_proceso) do
    estado_limpio =
      case Map.get(estado.sesiones, usuario) do
        %{pid: pid_anterior, monitor: monitor_anterior} = ses_prev ->
          Process.demonitor(monitor_anterior, [:flush])

          estado
          |> eliminar_indice_pid(pid_anterior)
          |> eliminar_sesion_de_usuario(usuario)
          |> then(fn est -> {est, ses_prev[:partida]} end)

        _otro ->
          {estado, nil}
      end

    {estado_base, partida_prev} = estado_limpio
    monitor = Process.monitor(pid_proceso)

    nuevas_sesiones =
      Map.put(
        estado_base.sesiones,
        usuario,
        %{pid: pid_proceso, monitor: monitor, partida: partida_prev}
      )

    nuevos_procesos = Map.put(estado_base.procesos, pid_proceso, usuario)

    {:ok, %{estado_base | sesiones: nuevas_sesiones, procesos: nuevos_procesos}}
  end

  defp eliminar_sesion(estado, usuario) do
    case Map.get(estado.sesiones, usuario) do
      %{pid: pid_proceso, monitor: monitor} ->
        Process.demonitor(monitor, [:flush])

        estado
        |> eliminar_indice_pid(pid_proceso)
        |> eliminar_sesion_de_usuario(usuario)

      _otro ->
        estado
    end
  end

  defp asegurar_conectado(estado, usuario) do
    if Map.has_key?(estado.sesiones, usuario) do
      :ok
    else
      {:error, :not_connected}
    end
  end

  defp eliminar_indice_pid(estado, pid_proceso),
    do: %{estado | procesos: Map.delete(estado.procesos, pid_proceso)}

  defp eliminar_sesion_de_usuario(estado, usuario),
    do: %{estado | sesiones: Map.delete(estado.sesiones, usuario)}

  defp autenticar_o_registrar(usuario, clave) do
    case UserManager.obtener_usuario(usuario) do
      %User{clave: ^clave} ->
        {:ok, :logged_in}

      %User{} ->
        {:error, :invalid_clave}

      nil ->
        case UserManager.registrar_usuario(usuario, clave) do
          :ok -> {:ok, :registered}
          :error -> {:error, :user_file}
        end

      :error ->
        {:error, :user_file}
    end
  end

  def guardar_resultado(fecha_iso, tema, puntajes) do
    linea_puntajes =
      puntajes
      |> Enum.map(fn {usuario, puntaje} -> "#{usuario}:#{puntaje}" end)
      |> Enum.join("|")

    File.write!(@archivo_resultados, "#{fecha_iso};#{tema};#{linea_puntajes}\n", [:append])
  end
end
