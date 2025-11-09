defmodule ClienteGenServer do
  use GenServer
  @doc """
  Inicia el GenServer del cliente con el estado inicial.
  El estado inicial es un mapa con las siguientes claves:
    - :usuario - el nombre del usuario conectado (o nil si no hay sesión)
    - :partida - el PID de la última partida conocida (o nil si no hay ninguna)
    - :partidas_listadas - la lista de partidas listadas (o [] si no hay ninguna)
    - :estado - el estado del cliente (:esperando o :en_partida)
  """
  def start_link do
    GenServer.start_link(
      __MODULE__,
    %{usuario: nil, partida: nil, partidas_listadas: [], estado: :esperando},
    name: __MODULE__)
  end

  @doc """
  Obtiene el estado completo del GenServer del cliente.
  Retorna un mapa con el estado actual.
  """
  def get_estado do
    GenServer.call(__MODULE__, :get_estado)
  end

  @doc """
  Establece el usuario conectado en el GenServer del cliente.
  Recibe el nombre del usuario como argumento.
  """
  def set_usuario(usuario) do
    GenServer.cast(__MODULE__, {:set_usuario, usuario})
  end

  @doc """
  Obtiene el usuario conectado en el GenServer del cliente.
  Retorna el nombre del usuario o nil si no hay sesión activa.
  """
  def get_usuario do
    GenServer.call(__MODULE__, :get_usuario)
  end

  @doc """
  Establece el PID de la última partida conocida en el GenServer del cliente.
  Recibe el PID de la partida como argumento.
  """
  def set_ultima_partida(pid) do
    GenServer.cast(__MODULE__, {:set_ultima_partida, pid})
  end

  @doc """
  Obtiene el PID de la última partida conocida en el GenServer del cliente.
  Retorna el PID de la partida o nil si no hay ninguna.
  """
  def get_ultima_partida do
    GenServer.call(__MODULE__, :get_ultima_partida)
  end

  @doc """
  Establece la lista de partidas listadas en el GenServer del cliente.
  Recibe la lista de partidas como argumento.
  """
  def set_partidas_listadas(partidas) do
    GenServer.cast(__MODULE__, {:set_partidas_listadas, partidas})
  end

  @doc """
  Obtiene la lista de partidas listadas en el GenServer del cliente.
  Retorna la lista de partidas.
  """
  def get_partidas_listadas do
    GenServer.call(__MODULE__, :get_partidas_listadas)
  end

  @doc """
  Establece el estado del cliente en el GenServer.
  Recibe el nuevo estado (:esperando o :en_partida) como argumento.
  """
  def set_estado(estado) do
    GenServer.cast(__MODULE__, {:set_estado, estado})
  end

  @doc """
  Obtiene el estado del cliente en el GenServer.
  Retorna el estado actual (:esperando o :en_partida).
  """
  def set_estado_cliente(estado) do
    GenServer.cast(__MODULE__, {:set_estado_cliente, estado})
  end

  @doc """
  Obtiene el estado del cliente en el GenServer.
  Retorna el estado actual (:esperando o :en_partida).
  """
  def get_estado_cliente do
    GenServer.call(__MODULE__, :get_estado_cliente)
  end

  @doc """
  Inicializa el GenServer con el estado dado.
  """
  def init(estado) do
    {:ok, estado}
  end

  @doc """
  Manejadores de llamadas síncronas ("handle_call/3") del GenServer.

  Estos mensajes permiten consultar el estado del cliente y de las partidas.
  Los tipos de llamadas son:

    * ":get_estado" - Devuelve todo el estado del GenServer.
    * ":get_estado_cliente" - Devuelve solo el estado actual del cliente.
    * ":get_usuario" - Devuelve el usuario almacenado en el estado.
    * ":get_ultima_partida" - Devuelve el PID de la última partida.
    * ":get_partidas_listadas" - Devuelve la lista de partidas listadas.
  """
  def handle_call(:get_estado, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:get_estado_cliente, _from, state) do
    {:reply, state.estado, state}
  end

  def handle_call(:get_usuario, _from, state) do
    {:reply, state.usuario, state}
  end

  def handle_call(:get_ultima_partida, _from, state) do
    {:reply, state.partida, state}
  end

  def handle_call(:get_partidas_listadas, _from, state) do
    {:reply, state.partidas_listadas, state}
  end

  @doc """
  Manejadores de mensajes asíncronos ("handle_cast/2") del GenServer.

  Estos mensajes permiten actualizar el estado del cliente o manejar eventos
  de trivia. Los tipos de mensajes son:

    * "{:set_usuario, usuario}" - Actualiza el usuario en el estado.
    * "{:set_ultima_partida, pid}" - Guarda el PID de la última partida.
    * "{:set_partidas_listadas, partidas}" - Actualiza la lista de partidas.
    * "{:set_estado_cliente, nuevo_estado}" - Cambia el estado del cliente.
    * "{:trivia_evento, {:nueva_ronda, ronda, datos}}" - Inicia una nueva ronda.
    * "{:trivia_evento, {:respuesta, usuario, ronda, :correcta}}" - Respuesta correcta.
    * "{:trivia_evento, {:respuesta, usuario, ronda, :incorrecta}}" - Respuesta incorrecta.
    * "{:trivia_evento, {:fin_partida, ganador, puntajes}}" - Termina la partida.
    * "{:trivia_evento, {:fin_partida_cancelada, miembro}}" - Partida cancelada.
  """
  def handle_cast({:set_usuario, usuario}, state) do
    {:noreply, %{state | usuario: usuario}}
  end

  def handle_cast({:set_ultima_partida, pid}, state) do
    {:noreply, %{state | partida: pid}}
  end

  def handle_cast({:set_partidas_listadas, partidas}, state) do
    {:noreply, %{state | partidas_listadas: partidas}}
  end

  def handle_cast({:set_estado_cliente, nuevo_estado}, state) do
    {:noreply, %{state | estado: nuevo_estado}}
  end

  def handle_cast({:trivia_evento, {:nueva_ronda, ronda, datos}}, state) do
    IO.puts("\nRonda #{ronda}: #{datos.pregunta}")
    datos.respuestas
    |> Enum.each(fn txt -> IO.puts("  #{txt}.") end)
    IO.puts("Responde con: answer #{ronda} <a|b|c|d>\n")
    IO.write("cliente> ")
    {:noreply, %{state | estado: :en_partida}}
  end

  def handle_cast({:trivia_evento, {:respuesta, usuario, ronda, :correcta}}, state) do
    IO.puts("#{usuario} respondió correctamente en la ronda #{ronda}.\n")
    {:noreply, state}
  end

  def handle_cast({:trivia_evento, {:respuesta, usuario, ronda, :incorrecta}}, state) do
    IO.puts("#{usuario} respondió incorrectamente en la ronda #{ronda}.\n")
    {:noreply, state}
  end

  def handle_cast({:trivia_evento, {:fin_partida, {usuario, puntaje}, puntajes}}, state) do
    IO.puts("Partida terminada. Ganador: #{usuario} con #{puntaje} puntos.")
    IO.puts("Puntajes:")
    Enum.each(puntajes, fn {u, s} -> IO.puts("  #{u}: #{s} puntos.") end)
    IO.write("cliente> ")
    set_ultima_partida(nil)
    {:noreply, %{state | estado: :esperando}}
  end

  @impl true
  def handle_cast({:trivia_evento, {:fin_partida_cancelada, miembro}}, state) do
    IO.puts("La partida fue cancelada por #{inspect(miembro)}.")
    IO.write("cliente> ")
    set_ultima_partida(nil)
    {:noreply, %{state | estado: :esperando}}
  end
end

defmodule ClienteCLI do
  @moduledoc """
  Módulo que implementa la interfaz de línea de comandos del cliente.
  Permite al usuario interactuar con el servidor de trivia mediante comandos.
  """
  @nodo_server :servidor@localhost
  @nombre_server Trivia.Server
  @cookie :cookie
  @temas ["biologia","historia","matematicas","quimica","fisica"]
  @contestaciones_validas ["a", "b", "c", "d"]
  @comandos_libres ["help", "connect"]

  @doc """
  Funciones para interactuar con el GenServer del cliente.
  """
  def set_usuario(usuario), do: ClienteGenServer.set_usuario(usuario)
  def get_usuario, do: ClienteGenServer.get_usuario()
  def clear_usuario, do: ClienteGenServer.set_usuario(nil)

  @doc """
  Funciones para manejar la última partida conocida.
  """
  def set_ultima_partida(pid), do: ClienteGenServer.set_ultima_partida(pid)
  def get_ultima_partida, do: ClienteGenServer.get_ultima_partida()
  def clear_ultima_partida, do: ClienteGenServer.set_ultima_partida(nil)

  @doc """
  Funciones para manejar la lista de partidas listadas.
  """
  def set_partidas_listadas(lista), do: ClienteGenServer.set_partidas_listadas(lista)
  def get_partidas_listadas, do: ClienteGenServer.get_partidas_listadas()
  def clear_partidas_listadas, do: ClienteGenServer.set_partidas_listadas([])

  @doc """
  Funciones para manejar el estado del cliente.
  """
  def set_estado_cliente(estado), do: ClienteGenServer.set_estado_cliente(estado)
  def get_estado_cliente, do: ClienteGenServer.get_estado_cliente()

  @doc """
  Revisa si el comando dado requiere una sesión activa.
  Si el comando está en la lista de comandos libres, retorna :ok.
  """
  def revisar_conexion(comando) do
    if Enum.member?(@comandos_libres, comando) do
      :ok
    else
      case get_usuario() do
        nil -> {:error, "No hay sesión activa. Usa 'connect <usuario> <clave>'."}
        _ -> :ok
      end
    end
  end

  @doc """
  Crea un nombre de nodo único para el cliente utilizando un UUID.
  """
  def crear_nombre_nodo do
    uuid = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
    String.to_atom("cliente_" <> uuid <> "@localhost")
  end

  @doc """
  Inicia el cliente, conectándose al nodo servidor y comenzando el bucle de comandos.
  """
  def start do
    ClienteGenServer.start_link()
    nodo = crear_nombre_nodo()
    IO.puts("Iniciando cliente en nodo #{nodo}...")
    Node.start(nodo, :shortnames)
    Node.set_cookie(@cookie)

    case Node.connect(@nodo_server) do
      true ->
        IO.puts("Conectado al nodo servidor #{@nodo_server}.")
        loop()
      false ->
        IO.puts("No se pudo conectar al nodo servidor #{@nodo_server}.")
    end
  end

  @doc """
  Bucle principal que lee comandos desde la línea de comandos del cliente.
  Procesa cada comando utilizando la función "handle".
  """
  def loop do
    case IO.gets("cliente> ") |> String.trim() do
      :eof -> loop()
      "" -> loop()
      comando ->
        comando_separado = String.split(comando, ~r/\s+/, trim: true)
        case revisar_conexion(List.first(comando_separado)) do
          :ok -> handle(comando_separado)
          {:error, mensaje} -> IO.puts(mensaje)
        end
        loop()
    end
  end

  @doc """
  Maneja diversos comandos enviados desde la línea de comandos del cliente.

  Los comandos disponibles son los siguientes:
  - "help": Muestra una lista de los comandos disponibles.
  - "connect <usuario> <clave>": Conecta al usuario con el servidor si no hay sesión activa.
  - "disconnect": Desconecta al usuario actual.
  - "list_games": Lista las partidas disponibles en el servidor.
  - "ranking": Muestra el ranking global o por tema.
  - "create_game tema=<Tema> preguntas=<N> tiempo=<seg>": Crea una nueva partida con los parámetros dados.
  - "join_game <índice>": Permite unirse a una partida de la lista mostrada previamente.
  - "start_game": Inicia la partida seleccionada si es el creador.
  - "answer <pregunta> <letra>": Envía la respuesta a una pregunta en curso.
  - "score": Muestra el puntaje actual del usuario.

  Cada comando es gestionado por una cláusula distinta de la función "handle", que valida los parámetros y cuando es necesario, interactúa con el servidor de trivia.
  """
  def handle(["help"]) do
    IO.puts("""
    Comandos:
      help
      connect <usuario> <clave>
      disconnect

      list_games
      create_game tema=<Tema> preguntas=<N> tiempo=<seg>

      join_game                # usa la última partida conocida
      join_game <indice>       # según la última lista mostrada con list_games

      start_game               # inicia la última partida (si eres el creador)

      answer <pregunta> <letra>

      score
      ranking
      ranking <tema>
    """)
  end

  def handle(["connect", usuario, password]) do
    if get_usuario() == nil do
      pid_genserver = Process.whereis(ClienteGenServer)
      case GenServer.call({@nombre_server, @nodo_server}, {:connect, usuario, password, pid_genserver}) do
        {:ok, _info} ->
          set_usuario(usuario)
          IO.puts("Conectado como #{usuario}")
        {:error, :already_connected} ->
          IO.puts("El usuario #{usuario} ya tiene una sesión activa.")
        {:error, :invalid_clave} ->
          IO.puts("La clave del usuario #{usuario} es incorrecta.")
        {:error, motivo} ->
          IO.puts("No se pudo conectar: #{inspect(motivo)}.")
      end
    else
      IO.puts("Ya hay una sesión activa. Desconéctate primero.")
    end
  end

  def handle(["disconnect"]) do
    case get_usuario() do
      nil ->
        IO.puts("No hay sesión activa.")
      usuario ->
        _ = GenServer.call({@nombre_server, @nodo_server}, {:disconnect, usuario})
        clear_usuario()
        clear_ultima_partida()
        clear_partidas_listadas()
        IO.puts("Sesión cerrada.")
    end
  end

  def handle(["list_games"]) do
    case GenServer.call({@nombre_server, @nodo_server}, :list_games) do
      lista when is_list(lista) ->
        set_partidas_listadas(lista)
        if lista == [] do
          IO.puts("PARTIDAS: []")
        else
          IO.puts("PARTIDAS:")
          lista
          |> Enum.with_index(1)
          |> Enum.each(fn {pid, indice} -> IO.puts("  #{indice}) #{inspect(pid)}") end)
        end
      otro ->
        IO.puts("Error al listar: #{inspect(otro)}")
    end
  end

  def handle(["ranking"]),
    do: IO.inspect(GenServer.call({@nombre_server, @nodo_server}, {:global_ranking, nil}), label: "RANKING GLOBAL")

  def handle(["ranking", tema]) do
    if tema in @temas do
      IO.inspect(GenServer.call({@nombre_server, @nodo_server}, {:global_ranking, tema}), label: "RANKING POR TEMA")
    else
      IO.puts("Tema no reconocido: #{tema}. Temas válidos: #{Enum.join(@temas, ", ")}")
    end
  end

  def handle(["create_game", tema, preguntas, tiempo]) do
    case configuracion_es_valida?(tema, preguntas, tiempo) do
      %{} = cfg ->
        case {get_usuario(), get_ultima_partida()} do
          {nil, _} ->
            IO.puts("Debes conectarte primero: connect <usuario> <clave>")

          {usuario, nil} ->
            case GenServer.call({@nombre_server, @nodo_server}, {:create_game, cfg, usuario}) do
              {:ok, pid_partida} ->
                set_ultima_partida(pid_partida)
                IO.puts("La partida ha sido creada.")

              otro ->
                IO.puts("No se pudo crear la partida: #{inspect(otro)}")
            end
          {_, _} ->
            IO.puts("Aún no has terminado tu partida actual. Espera a que termine antes de crear una.")
        end

      errores ->
        IO.puts("Errores en configuración de partida:")
        Enum.each(errores, fn error -> IO.puts("  - #{error}") end)
    end
  end

def handle(["join_game", indice]) do
  case Integer.parse(indice) do
    {entero, ""} when entero >= 1 ->
      case {get_usuario(), get_partidas_listadas()} do
        {nil, _} ->
          IO.puts("Debes conectarte primero: connect <usuario> <clave>")

        {_, nil} ->
          IO.puts("No hay lista en memoria. Ejecuta 'list_games' primero.")

        {_, []} ->
          IO.puts("No hay partidas disponibles. Ejecuta 'list_games' primero.")

        {usuario, lista} ->
          case Enum.at(lista, entero - 1) do
            {pid_partida, _creador} when is_pid(pid_partida) ->
              if get_estado_cliente() == :esperando do
                case GenServer.call({@nombre_server, @nodo_server}, {:join_game, pid_partida, usuario}) do
                  {:ok, :ya_estaba} ->
                    IO.puts("Ya estabas en la partida.")

                  {:ok, :unido} ->
                    IO.puts("Se ha unido a la partida.")

                  {:error, :ya_iniciada} ->
                    IO.puts("La partida ya ha comenzado. No se puede unir.")

                  {:error, :llena} ->
                    IO.puts("La partida está llena. No se puede unir.")

                  {:error, :partida_no_activa} ->
                    IO.puts("La partida ya no existe.")

                  {:error, :ya_en_otra_partida} ->
                    IO.puts("Ya estás en otra partida. No se puede unir.")

                  {:error, motivo} ->
                    IO.puts("No se pudo unir a la partida: #{inspect(motivo)}")
                end

                set_ultima_partida(pid_partida)
              else
                IO.puts(
                  "Aún no has terminado tu partida actual. Espera a que termine antes de unirte a otra."
                )
              end

            nil ->
              IO.puts("Índice fuera de rango.")
          end
      end

    _ ->
      IO.puts("Uso: join_game <índice>")
  end
end

  def handle(["start_game"]) do
    case {get_ultima_partida(), get_usuario()} do
      {nil, _} ->
        IO.puts("No hay partida seleccionada. Usa 'join_game' o 'list_games' primero.")

      {_, nil} ->
        IO.puts("Debes conectarte primero: connect <usuario> <clave>")

      {pid_partida, usuario} when is_pid(pid_partida) ->
        case GenServer.call({@nombre_server, @nodo_server}, {:start_game, pid_partida, usuario}) do
          {:error, _} -> IO.puts("Solo el creador puede iniciar la partida.")
          {:ok, :iniciada} -> IO.puts("La partida ha sido iniciada.")
        end

      {otra, _} ->
        IO.puts("Referencia de partida inválida en memoria: #{inspect(otra)}")
    end
  end

  def handle(["answer", indice_pregunta, letra]) do
    if get_estado_cliente() == :en_partida do
      usuario = get_usuario()

      cond do
        get_ultima_partida() == nil ->
          IO.puts("No hay partida seleccionada. Usa 'join_game' o 'list_games' primero.")

        !es_entero?(indice_pregunta) or !(letra in @contestaciones_validas) ->
          IO.puts("Formato incorrecto. Uso: answer <pregunta> <letra>  (letra en a|b|c|d)")

        true ->
          pid_partida = get_ultima_partida()
          pregunta_entera = String.to_integer(indice_pregunta)
          case GenServer.call({@nombre_server, @nodo_server}, {:answer, pid_partida, usuario, pregunta_entera, letra}) do
            {:ok, _} ->
              IO.puts("Respuesta enviada.")
            {:error, :no_iniciada} ->
              IO.puts("La partida no ha comenzado.")
            {:error, :ronda_incorrecta} ->
              IO.puts("No es la ronda correcta para responder.")
            {:error, :ya_respondio} ->
              IO.puts("Ya has respondido esta pregunta.")
            {:error, motivo} ->
              IO.puts("No se pudo enviar la respuesta: #{inspect(motivo)}")
          end
      end
    else
      IO.puts("No estás en una partida activa.")
    end
  end

  def handle(["score"]) do
    case get_usuario() do
      nil -> IO.puts("No hay sesión activa.")
      usuario ->
        case GenServer.call({@nombre_server, @nodo_server}, {:score, usuario}) do
          {:ok, puntaje} ->
            IO.puts("Puntaje actual de #{usuario}: #{puntaje}")
          {:error, motivo} ->
            IO.puts("No se pudo obtener el puntaje: #{inspect(motivo)}")
        end
    end
  end

  def handle(_comando) do
    IO.puts("Comando no reconocido. Usa 'help'.")
  end

  @doc """
  Valida los parámetros de configuración de una partida.
  Retorna un mapa con la configuración válida o una lista de errores.
  """
  def configuracion_es_valida?(tema, pregunta, tiempo) do
    {errores1, tema_valido} = verificar_tema([], tema)
    {errores2, preguntas_validas} = verificar_pregunta(errores1, pregunta)
    {errores3, tiempo_valido} = verificar_tiempo(errores2, tiempo)

    if errores3 == [] do
      %{
        tema: tema_valido,
        preguntas: preguntas_validas,
        tiempo: tiempo_valido
      }
    else
      errores3
    end
  end

  @doc """
  Verifica que el tema dado sea válido.
  Retorna una tupla con la lista de errores y el tema válido (o nil si no es válido).
  """
  def verificar_tema(errores, tema_dado) do
    case String.split(tema_dado, "=") do
      ["tema", tema] ->
        if tema in @temas do
          {errores, tema}
        else
          {["Tema no reconocido: #{tema_dado}. Temas válidos: #{Enum.join(@temas, ", ")}" | errores], nil}
        end
      _ ->
        {["Formato incorrecto para tema: #{tema_dado}. Uso: tema=<Tema>" | errores], nil}
    end
  end

  @doc """
  Verifica que el número de preguntas dado sea válido.
  Retorna una tupla con la lista de errores y el número de preguntas válido (o nil si no es válido).
  """
  def verificar_pregunta(errores, pregunta_dada) do
    case String.split(pregunta_dada, "=") do
      ["preguntas", pregunta] ->
        case Integer.parse(pregunta) do
          {entero, ""} ->
            if entero >= 1 and entero <= 10 do
              {errores, entero}
            else
              {["Número de preguntas inválido: #{pregunta_dada}. Debe estar entre 1 y 10." | errores], nil}
            end
          _ ->
            {["Número de preguntas inválido: #{pregunta_dada}. Debe ser un entero." | errores], nil}
        end
      _ ->
        {["Formato incorrecto para preguntas: #{pregunta_dada}. Uso: preguntas=<N>" | errores], nil}
    end
  end

  @doc """
  Verifica que el tiempo dado sea válido.
  Retorna una tupla con la lista de errores y el tiempo válido (o nil si no es válido).
  """
  def verificar_tiempo(errores, tiempo_dado) do
    case String.split(tiempo_dado, "=") do
      ["tiempo", tiempo] ->
        case Integer.parse(tiempo) do
          {entero, ""} ->
            if entero >= 3 and entero <= 15 do
              {errores, entero }
            else
              {["Tiempo inválido: #{tiempo_dado}. Debe estar entre 3 y 15 segundos." | errores], nil}
            end
          _ ->
            {["Tiempo inválido: #{tiempo_dado}. Debe ser un entero." | errores], nil}
        end
      _ ->
        {["Formato incorrecto para tiempo: #{tiempo_dado}. Uso: tiempo=<seg>" | errores], nil}
    end
  end

  @doc """
  Verifica si una cadena representa un entero válido.
  Retorna true si es un entero, false en caso contrario.
  """
  def es_entero?(numero) do
    case Integer.parse(numero) do
      {_entero, ""} -> true
      _ -> false
    end
  end
end

ClienteCLI.start()
