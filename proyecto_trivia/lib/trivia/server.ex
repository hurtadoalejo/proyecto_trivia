defmodule Trivia.Server do
  @moduledoc """
  Servidor central que maneja conexiones de clientes, sesiones de usuarios y
  reenvío de mensajes a las partidas activas.
  """
  use GenServer
  @archivo_resultados "data/results.csv"


  @doc """
  Iniciar el servidor Trivia.Server
  """
  def start_link(opciones),
    do: GenServer.start_link(__MODULE__, opciones, name: __MODULE__)

  @doc """
  Inicializar el servidor Trivia.Server
  Estado inicial:
   - sesiones: %{usuario => %{pid: pid, monitor: ref, partida: pid_partida | nil}}
  """
  @impl true
  def init(_argumento_inicial) do
    #%{usuario => %{pid: pid, monitor: ref, partida: pid_partida | nil}}
    {:ok, %{}}
  end

  @doc """
  Manejar mensajes asíncronos (casts) del cliente, los mensajes incluyen:
   - difundir_a_partida(pid_partida, contenido): Reenviar un mensaje a todos los clientes en una partida
   - difundir_a_partida(pid_partida, {:fin_partida, ganador, puntajes}): Reenviar fin de partida y limpiar sesiones
  """
  @impl true
  def handle_cast({:difundir_a_partida, pid_partida, {:fin_partida, ganador, puntajes}}, estado) do
    Enum.each(estado, fn {_usuario, %{pid: pid_cliente, partida: partida_actual}} ->
      if partida_actual == pid_partida do
        GenServer.cast(pid_cliente, {:trivia_evento, {:fin_partida, ganador, puntajes}})
      end
    end)

    nuevo_estado =
      Enum.map(estado, fn {usuario, datos} ->
        if datos.partida == pid_partida do
          {usuario, %{datos | partida: nil}}
        else
          {usuario, datos}
        end
      end)
      |> Map.new()

    {:noreply, nuevo_estado}
  end

  @impl true
  def handle_cast({:difundir_a_partida, pid_partida, contenido}, estado) do
    Enum.each(estado, fn {_usuario, %{pid: pid_cliente, partida: pid_sesion}} ->
      if pid_sesion == pid_partida do
        GenServer.cast(pid_cliente, {:trivia_evento, contenido})
      end
    end)
    {:noreply, estado}
  end

  @doc """
  Manejar llamadas síncronas del cliente, las llamadas incluyen:
   - connect(usuario, clave, pid_cliente): Conecta a un usuario, autenticándolo o registrándolo
   - disconnect(usuario): Desconecta a un usuario
   - list_games(): Lista las partidas activas
   - create_game(opciones, creador): Crea una nueva partida
   - join_game(pid_partida, usuario): Une a un usuario a una partida
   - start_game(pid_partida, usuario): Inicia una partida
   - answer(pid_partida, usuario, ronda, opcion): Envía una respuesta a una pregunta
   - score(usuario): Consulta el puntaje total de un usuario
   - global_ranking(tema | nil): Consulta el ranking global, opcionalmente filtrado por tema
  """
  @impl true
  def handle_call({:connect, usuario, clave, pid_cliente}, _from, estado) do
    if Map.has_key?(estado, usuario) do
      {:reply, {:error, :already_connected}, estado}
    else
      case autenticar_o_registrar(usuario, clave) do
        {:ok, exito} ->
          {:ok, nuevo_estado} = poner_sesion(estado, usuario, pid_cliente)
          {:reply, {:ok, exito}, nuevo_estado}

        {:error, motivo} ->
          {:reply, {:error, motivo}, estado}
      end
    end
  end

  @impl true
  def handle_call({:disconnect, usuario}, _from, estado) do
    {:reply, :ok, eliminar_sesion(estado, usuario)}
  end

  @impl true
  def handle_call(:list_games, _from, estado) do
    partidas_vivas =
      Trivia.Supervisor.list_games()
      |> Enum.map(fn {_, pid_partida, _, _} ->
        {:ok, creador} = GenServer.call(pid_partida, :get_creador)
        {pid_partida, creador}
      end)
      |> Enum.filter(fn {pid, _creador} -> Process.alive?(pid) end)

    {:reply, partidas_vivas, estado}
  end

  @impl true
  def handle_call({:create_game, opciones, creador}, _from, estado) do
    case Trivia.Supervisor.start_game(opciones) do
      {:ok, pid_partida} ->
        GenServer.cast(pid_partida, {:establecer_creador, creador})

        nuevo_estado =
        if Map.has_key?(estado, creador) do
          Map.update!(estado, creador, fn sesion -> %{sesion | partida: pid_partida} end)
        else
          estado
        end

        {:ok, :unido} = GenServer.call(pid_partida, {:join, creador})
        {:reply, {:ok, pid_partida}, nuevo_estado}

      {:error, motivo} ->
        {:reply, {:error, motivo}, estado}
    end
  end

  @impl true
  def handle_call({:join_game, pid_partida, usuario}, _desde, estado) do
    case asegurar_conectado(estado, usuario) do
      :ok ->
        sesion = Map.get(estado, usuario)

        cond do
          sesion.partida != nil and sesion.partida != pid_partida ->
            {:reply, {:error, :ya_en_otra_partida}, estado}

          true ->
            respuesta = GenServer.call(pid_partida, {:join, usuario})

            case respuesta do
              {:ok, _} ->
                nuevo_estado =
                  Map.update!(estado, usuario, fn datos ->
                    %{datos | partida: pid_partida}
                  end)

                {:reply, respuesta, nuevo_estado}

              _otro ->
                {:reply, respuesta, estado}
            end
        end

      {:error, motivo} ->
        {:reply, {:error, motivo}, estado}
    end
  end

  @impl true
  def handle_call({:start_game, pid_partida, usuario}, _from, estado) do
    respuesta =
    case GenServer.call(pid_partida, {:start, usuario}) do
      {:error, motivo} ->
        {:error, motivo}
      {:ok, :iniciada} ->
        {:ok, :iniciada}
    end

    {:reply, respuesta, estado}
  end

  @impl true
  def handle_call({:answer, pid_partida, usuario, ronda, opcion}, _from, estado) do
    case asegurar_conectado(estado, usuario) do
      :ok ->
        respuesta = GenServer.call(pid_partida, {:answer, usuario, ronda, opcion})
        {:reply, respuesta, estado}

      {:error, motivo} ->
        {:reply, {:error, motivo}, estado}
    end
  end

  @impl true
  def handle_call({:score, usuario}, _from, estado) do
    case UserManager.consultar_puntaje_total(usuario) do
      {:ok, _usuario, total} ->
        {:reply, {:ok, total}, estado}

      {:error, motivo} ->
        {:reply, {:error, motivo}, estado}
    end
  end

  @impl true
  def handle_call({:global_ranking, nil}, _from, estado) do
    ranking = UserManager.consultar_puntajes()
    {:reply, ranking, estado}
  end

  @impl true
  def handle_call({:global_ranking, tema}, _from, estado) do
    ranking = UserManager.consultar_puntajes_tema(tema)
    {:reply, ranking, estado}
  end

  @doc """
  Manejar desconexión de cliente (limpieza automática)
  1) Buscar el usuario asociado al PID muerto
  2) Eliminar índice de PID y sesión del usuario
  3) Si el usuario estaba en una partida, sacarlo de la partida
  """
  @impl true
  def handle_info({:DOWN, _monitor, :process, pid_muerto, _razon}, estado) do
    case Enum.find(estado, fn {_usuario, datos} -> datos.pid == pid_muerto end) do
      {usuario, %{partida: pid_partida}} ->

        nuevo_estado = eliminar_sesion_de_usuario(estado, usuario)

        if pid_partida do
          GenServer.cast(pid_partida, {:forzar_salida, usuario})
        end

        {:noreply, nuevo_estado}

      nil ->
        {:noreply, estado}
    end
  end

  @doc """
  Crear una nueva sesión para un usuario conectado
  1) Monitorear el proceso del cliente
  2) Agregar la sesión al estado
  3) Devolver el nuevo estado
  """
  def poner_sesion(estado, usuario, pid_proceso) do
    monitor = Process.monitor(pid_proceso)
    nuevo_estado =
      Map.put(
        estado,
        usuario,
        %{pid: pid_proceso, monitor: monitor, partida: nil}
      )

    {:ok, nuevo_estado}
  end

  @doc """
  Eliminar la sesión de un usuario conectado
  1) Buscar la sesión del usuario
  2) Desmonitorear el proceso del cliente
  3) Eliminar la sesión del usuario del estado
  4) Devolver el nuevo estado
  """
  def eliminar_sesion(estado, usuario) do
    case Map.get(estado, usuario) do
      %{monitor: monitor} ->
        Process.demonitor(monitor, [:flush])
        eliminar_sesion_de_usuario(estado, usuario)
      _otro ->
        estado
    end
  end

  @doc """
  Asegurar que un usuario esté conectado
  """
  def asegurar_conectado(estado, usuario) do
    if Map.has_key?(estado, usuario) do
      :ok
    else
      {:error, :not_connected}
    end
  end

  @doc """
  Eliminar la sesión de un usuario
  """
  def eliminar_sesion_de_usuario(estado, usuario),
    do: Map.delete(estado, usuario)

  @doc """
  Autenticar o registrar un usuario
  1) Si el usuario existe y la clave coincide, autenticar
  2) Si el usuario existe y la clave no coincide, error
  3) Si el usuario no existe, registrarlo
  """
  def autenticar_o_registrar(usuario, clave_dada) do
    case UserManager.obtener_usuario(usuario) do
      %User{clave: clave} when clave == clave_dada ->
        {:ok, :logged_in}

      %User{} ->
        {:error, :invalid_clave}

      nil ->
        case UserManager.registrar_usuario(usuario, clave_dada) do
          :ok -> {:ok, :registered}
          :error -> {:error, :user_file}
        end

      :error ->
        {:error, :user_file}
    end
  end

  @doc """
  Guardar resultado de partida en archivo CSV
  Formato:
  fecha_iso;tema;usuario1:puntaje1|usuario2:puntaje2|...
  """
  def guardar_resultado(fecha_iso, tema, puntajes) do
    linea_puntajes =
      puntajes
      |> Enum.map(fn {usuario, puntaje} -> "#{usuario}:#{puntaje}" end)
      |> Enum.join("|")

    File.write!(@archivo_resultados, "#{fecha_iso};#{tema};#{linea_puntajes}\n", [:append])
  end
end
