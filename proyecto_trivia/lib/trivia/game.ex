defmodule Trivia.Game do
  @moduledoc """
  Proceso de partida (cada juego es un GenServer independiente).

  Estado:
   - tema (tema)
   - total_preguntas
   - tiempo_por_pregunta
   - jugadores: %{usuario => %{puntaje: entero, respondio?: false}}
   - ronda_index (1..N)
   - preguntas: lista de preguntas %{pregunta, respuestas, respuesta_correcta}
   - comenzo? boolean
   - max_jugadores (por defecto 4)
   - temporizador (para el temporizador de cada ronda_index)
   - creador: usuario que creó la partida
  """
  use GenServer

  @default_max_jugadores 4

  @doc """
  Inicia un nuevo proceso de partida con las opciones dadas.
  """
  def start_link(opciones) do
    GenServer.start_link(__MODULE__, opciones)
  end

  @impl true
  def init(opciones) do
    tema = Map.get(opciones, :tema)
    total = Map.get(opciones, :preguntas)
    segundos = Map.get(opciones, :tiempo)

    preguntas =
      case GestorPreguntas.obtener_preguntas_aleatorias(tema, total) do
        {:error, _} -> []
        lista -> lista
      end

    {:ok,
      %{
       tema: tema,
       total_preguntas: total,
       tiempo_por_pregunta: segundos,
       preguntas: preguntas,
       ronda_index: 0,
       comenzo?: false,
       max_jugadores: @default_max_jugadores,
       creador: nil,
       jugadores: %{},
       temporizador: nil
     }}
  end

  @doc """
  Métodos asíncronos para interactuar con la partida.
  handle_cast({:establecer_creador, usuario_creador}, estado) Establece el creador de la partida.
  handle_cast({:forzar_salida, usuario}, estado) Forzar la salida de un usuario de la partida.
  """
  @impl true
  def handle_cast({:establecer_creador, usuario_creador}, estado) do
    nuevo_estado = %{estado | creador: usuario_creador}
    {:noreply, nuevo_estado}
  end

  @impl true
  def handle_cast({:forzar_salida, usuario}, estado) do
    cond do
      estado.creador == usuario and not estado.comenzo? ->
        Enum.each(estado.jugadores, fn {miembro, _} ->
          if miembro != usuario do
            GenServer.cast(Trivia.Server, {:difundir_a_partida, self(), {:fin_partida_cancelada, usuario}})
          end
        end)
        Trivia.Supervisor.terminar_partida(self())
        Process.exit(self(), :normal)
        {:noreply, estado}

      estado.comenzo? and Enum.count(estado.jugadores) == 1 ->
        Trivia.Supervisor.terminar_partida(self())
        Process.exit(self(), :normal)
        {:noreply, estado}

      Map.has_key?(estado.jugadores, usuario) ->
        nuevo_estado = %{estado | jugadores: Map.delete(estado.jugadores, usuario)}
        {:noreply, nuevo_estado}

      true ->
        {:noreply, estado}
    end
  end

  @doc """
  Maneja las llamadas síncronas para unirse, iniciar y responder en la partida.
  handle_call({:join, usuario}, _from, estado) Permite a un usuario unirse a la partida.
  handle_call({:start, usuario_llamador}, _from, estado) Inicia la partida si el llamador es el creador.
  handle_call({:answer, usuario, ronda_index, opcion}, _from, estado) Registra la respuesta de un jugador.
  handle_call(:get_creador, _from, estado) Devuelve el creador de la partida.
  """
  @impl true
  def handle_call({:join, usuario}, _from, estado) do
    cond do
      estado.comenzo? ->
        {:reply, {:error, :ya_iniciada}, estado}

      map_size(estado.jugadores) >= estado.max_jugadores ->
        {:reply, {:error, :llena}, estado}

      Map.has_key?(estado.jugadores, usuario) ->
        {:reply, {:ok, :ya_estaba}, estado}

      true ->
        nuevo_jugador = %{puntaje: 0, respondio?: false}
        nuevos_jugadores = Map.put(estado.jugadores, usuario, nuevo_jugador)
        nuevo_estado = %{estado | jugadores: nuevos_jugadores}
        {:reply, {:ok, :unido}, nuevo_estado}
    end
  end

  @impl true
  def handle_call({:start, usuario_llamador}, _from, estado) do
    cond do
      estado.creador != usuario_llamador ->
        {:reply, {:error, :no_autorizado}, estado}

      estado.comenzo? ->
        {:reply, {:error, :ya_iniciada}, estado}

      true ->
        estado = %{estado | comenzo?: true, ronda_index: 0}
        {:reply, {:ok, :iniciada}, siguiente_ronda_index(estado)}
    end
  end

  @impl true
  def handle_call({:answer, usuario, ronda_index, opcion}, _from, estado) do
    case verificar_condiciones_error(estado, usuario, ronda_index) do
      :ok ->
        letra_correcta = obtener_respuesta_correcta(estado, estado.ronda_index)
        es_correcta? = opcion == letra_correcta
        puntos = if es_correcta?, do: 10, else: -5

        nuevo_estado = actualizar_jugador(estado, usuario, puntos)
        resultado = if es_correcta?, do: :correcta, else: :incorrecta

        difundir_resultado(resultado, usuario, ronda_index)

        {:reply, {:ok, resultado}, nuevo_estado}

      {:error, reason} ->
        {:reply, {:error, reason}, estado}
    end
  end

  @impl true
  def handle_call(:get_creador, _from, estado) do
    {:reply, {:ok, estado.creador}, estado}
  end

  @doc """
  Maneja mensajes internos, como el temporizador de ronda_index.
  handle_info(:round_timeout, estado) Penaliza a los jugadores que no respondieron y avanza a la siguiente ronda_index.
  """
  @impl true
  def handle_info(:round_timeout, estado) do
    estado_penalizado = penalizar_no_respondidos(estado)
    nuevo_estado = siguiente_ronda_index(%{estado_penalizado | temporizador: nil})
    {:noreply, nuevo_estado}
  end

  @doc """
  Penaliza a los jugadores que no respondieron en la ronda actual.
  """
  def penalizar_no_respondidos(estado) do
    ronda_index = estado.ronda_index

    jugadores_actualizados =
      Enum.map(estado.jugadores, fn {usuario, datos} ->
        if datos.respondio? do
          {usuario, %{datos | respondio?: false}}
        else
          difundir_resultado(:incorrecta, usuario, ronda_index)
          {usuario, %{datos | puntaje: datos.puntaje - 5}}
        end
      end)

    nuevos_jugadores = Map.new(jugadores_actualizados)
    %{estado | jugadores: nuevos_jugadores}
  end

  @doc """
  Avanza a la siguiente ronda o finaliza la partida en caso de haber sido la última
  """
  def siguiente_ronda_index(estado) do
    if estado.temporizador, do: Process.cancel_timer(estado.temporizador)
    nueva_ronda_index = estado.ronda_index + 1

    if nueva_ronda_index > estado.total_preguntas do
      finalizar_partida(estado)
    else
      pregunta = Enum.at(estado.preguntas, nueva_ronda_index - 1)

      datos_mostrables = %{
        pregunta: pregunta.pregunta,
        respuestas: pregunta.respuestas
      }

      GenServer.cast(Trivia.Server, {:difundir_a_partida, self(), {:nueva_ronda, nueva_ronda_index, datos_mostrables}})

      referencia = Process.send_after(self(), :round_timeout, estado.tiempo_por_pregunta * 1000)
      %{estado | ronda_index: nueva_ronda_index, temporizador: referencia}
    end
  end

  @doc """
  Método que finaliza la partida
  1) Difunde quién fue el ganador y los puntajes finales
  2) Construye el formato para guardar en results.csv
  3) Termina el proceso
  """
  def finalizar_partida(estado) do
    puntajes_finales =
      Enum.reduce(estado.jugadores, %{}, fn {usuario, datos}, acc ->
        Map.put(acc, usuario, datos.puntaje)
      end)

    ganador = Enum.max_by(puntajes_finales, fn {_usuario, puntaje} -> puntaje end)

    Enum.each(puntajes_finales, fn {usuario, puntaje} ->
      UserManager.actualizar_puntaje_usuario(usuario, estado.tema, puntaje)
    end)

    GenServer.cast(Trivia.Server, {:difundir_a_partida, self(), {:fin_partida, ganador, puntajes_finales}})

    fecha =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.truncate(:second)
      |> NaiveDateTime.to_string()
      |> String.replace(" ", "|")

    Trivia.Server.guardar_resultado(fecha, estado.tema, puntajes_finales)

    if estado.temporizador, do: Process.cancel_timer(estado.temporizador)

    Trivia.Supervisor.terminar_partida(self())
    Process.exit(self(), :normal)

    estado
  end

  @doc """
  Verificar las condiciones del error antes de procesar la respuesta de un jugador
  """
  def verificar_condiciones_error(estado, usuario, ronda_index) do
    cond do
      not estado.comenzo? -> {:error, :no_iniciada}
      ronda_index != estado.ronda_index -> {:error, :ronda_incorrecta}
      estado.jugadores[usuario].respondio? == true -> {:error, :ya_respondio}
      true -> :ok
    end
  end

  @doc """
  Obtiene la respuesta correcta de una ronda específica
  """
  def obtener_respuesta_correcta(estado, ronda_index) do
    Enum.at(estado.preguntas, ronda_index - 1)
    |> then(fn mapa -> mapa.respuesta_correcta end)
  end

  @doc """
  Actualiza los datos de un jugador con los puntos ganados o perdidos
  Además se cambia el estado del jugador a respondio? = true
  """
  def actualizar_jugador(estado, usuario, puntos) do
    jugador = estado.jugadores[usuario]
    jugador_actualizado = %{jugador | puntaje: jugador.puntaje + puntos, respondio?: true}

    nuevos_jugadores = Map.put(estado.jugadores, usuario, jugador_actualizado)
    %{estado | jugadores: nuevos_jugadores}
  end

  @doc """
  Difunde el resultado de una respuesta ya sea correcta o incorrecta
  """
  def difundir_resultado(resultado, usuario, ronda_index) do
    GenServer.cast(
      Trivia.Server,
      {:difundir_a_partida, self(), {:respuesta, usuario, ronda_index, resultado}}
    )
  end
end
