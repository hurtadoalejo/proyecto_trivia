defmodule Trivia.Game do
  @moduledoc """
  Proceso de partida (cada juego es un GenServer independiente).

  Estado:
   - topic (tema)
   - total_questions
   - seconds_per_question
   - players: %{usuario => %{score: entero, answered_rounds: MapSet}}
   - round_index (1..N)
   - questions: lista de preguntas %{pregunta, respuestas, respuesta_correcta}
   - started? boolean
   - max_players (por defecto 4)
   - timer_ref (para el temporizador de cada ronda)
   - creador: usuario que creó la partida
  """

  use GenServer

  defstruct [
    :topic,
    :total_questions,
    :seconds_per_question,
    :questions,
    :round_index,
    :started?,
    :max_players,
    :creador,
    players: %{},
    timer_ref: nil
  ]

  @default_max_players 4

  # === Arranque ==================================================
  def start_link(opciones) do
    GenServer.start_link(__MODULE__, opciones)
  end

  @impl true
  def init(opciones) do
    tema = Map.fetch!(opciones, :tema)
    total = Map.get(opciones, :preguntas, 5)
    segundos = Map.get(opciones, :tiempo, 15)
    max_jugadores = Map.get(opciones, :max_jugadores, @default_max_players)

    preguntas =
      case GestorPreguntas.obtener_preguntas_aleatorias(tema, total) do
        {:error, _} -> []
        lista when is_list(lista) -> lista
      end

    {:ok,
     %__MODULE__{
       topic: tema,
       total_questions: total,
       seconds_per_question: segundos,
       questions: preguntas,
       round_index: 0,
       started?: false,
       max_players: max_jugadores,
       creador: nil,
       players: %{},
       timer_ref: nil
     }}
  end

  # === Lógica de comandos ========================================

  # Solo el servidor principal puede definir quién es el creador
  @impl true
  def handle_cast({:establecer_creador, usuario_creador}, estado) do
    nuevo_estado = %{estado | creador: usuario_creador}
    {:noreply, nuevo_estado}
  end

  @impl true
  def handle_cast({:forzar_salida, usuario}, estado) do
    nuevo_estado = %{estado | players: Map.delete(estado.players, usuario)}
    {:noreply, nuevo_estado}
  end

  # Unirse a una partida
  @impl true
  def handle_call({:join, usuario}, _from, estado) do
    cond do
      estado.started? ->
        {:reply, {:error, :ya_iniciada}, estado}

      map_size(estado.players) >= estado.max_players ->
        {:reply, {:error, :llena}, estado}

      Map.has_key?(estado.players, usuario) ->
        {:reply, {:ok, :ya_estaba}, estado}

      true ->
        nuevo_jugador = %{score: 0, answered_rounds: MapSet.new()}
        nuevo_estado = put_in(estado.players[usuario], nuevo_jugador)
        {:reply, {:ok, :unido}, nuevo_estado}
    end
  end

  # Solo el creador puede iniciar la partida
  @impl true
  def handle_call({:start, usuario_llamador}, _from, estado) do
    cond do
      estado.creador == nil ->
        {:reply, {:error, :sin_creador}, estado}

      estado.creador != usuario_llamador ->
        {:reply, {:error, :no_autorizado}, estado}

      estado.started? ->
        {:reply, {:error, :ya_iniciada}, estado}

      estado.questions == [] ->
        {:reply, {:error, :sin_preguntas}, estado}

      true ->
        estado = %{estado | started?: true, round_index: 0}
        {:reply, {:ok, :iniciada}, siguiente_ronda(estado)}
    end
  end

  # Registrar respuesta de un jugador
  @impl true
  def handle_call({:answer, usuario, ronda, opcion}, _from, estado) do
    cond do
      not estado.started? ->
        {:reply, {:error, :no_iniciada}, estado}

      ronda != estado.round_index ->
        {:reply, {:error, :ronda_incorrecta}, estado}

      not Map.has_key?(estado.players, usuario) ->
        {:reply, {:error, :no_en_partida}, estado}

      MapSet.member?(estado.players[usuario].answered_rounds, ronda) ->
        {:reply, {:error, :ya_respondio}, estado}

      true ->
        letra_correcta =
          case Enum.at(estado.questions, estado.round_index - 1) do
            %{respuesta_correcta: r} -> String.downcase(String.trim(r))
            _ -> "a"
          end

        es_correcta = String.downcase(String.trim(opcion)) == letra_correcta
        delta = if es_correcta, do: 10, else: -5

        jugador = estado.players[usuario]
        jugador_actualizado = %{
          jugador
          | score: jugador.score + delta,
            answered_rounds: MapSet.put(jugador.answered_rounds, ronda)
        }

        nuevo_estado = put_in(estado.players[usuario], jugador_actualizado)
        resultado_reply = if es_correcta, do: :correcta, else: :incorrecta

        # Difundir a todos que este usuario respondió (pero NO avanzar)
        GenServer.cast(
          Trivia.Server,
          {:difundir_a_partida, self(), {:respuesta, usuario, ronda, resultado_reply}}
        )

        {:reply, {:ok, resultado_reply}, nuevo_estado}
    end
  end

  @impl true
  def handle_call(:get_creador, _from, estado) do
    {:reply, {:ok, estado.creador}, estado}
  end

  # === Temporizador ==============================================
  @impl true
  def handle_info(:round_timeout, estado) do
    estado_penalizado = penalizar_no_respondidos(estado)
    nuevo_estado = siguiente_ronda(%{estado_penalizado | timer_ref: nil})
    {:noreply, nuevo_estado}
  end

  defp penalizar_no_respondidos(estado) do
    ronda = estado.round_index

    # Recorremos jugadores y penalizamos a quien no respondió esta ronda
    {jugadores_actualizados, _} =
      Enum.map_reduce(estado.players, false, fn {usuario, pj}, _acc ->
        ya_respondio = MapSet.member?(pj.answered_rounds, ronda)

        if ya_respondio do
          {{usuario, pj}, false}
        else
          pj2 = %{
            pj
            | score: pj.score - 5,
              answered_rounds: MapSet.put(pj.answered_rounds, ronda)
          }

          # Difundir a todos en la sala que este usuario quedó incorrecto por timeout
          GenServer.cast(
            Trivia.Server,
            {:difundir_a_partida, self(), {:respuesta, usuario, ronda, :incorrecta}}
          )

          {{usuario, pj2}, true}
        end
      end)

    %{estado | players: Map.new(jugadores_actualizados)}
  end

  defp siguiente_ronda(estado) do
    if estado.timer_ref, do: Process.cancel_timer(estado.timer_ref)
    nueva_ronda = estado.round_index + 1

    if nueva_ronda > estado.total_questions do
      finalizar_partida(estado)
    else
      pregunta = Enum.at(estado.questions, nueva_ronda - 1)

      # Emitir evento a los clientes de esta partida
      datos_mostrables = %{
        pregunta: pregunta.pregunta,
        respuestas: pregunta.respuestas
      }

      GenServer.cast(Trivia.Server, {:difundir_a_partida, self(), {:nueva_ronda, nueva_ronda, datos_mostrables}})

      ref = Process.send_after(self(), :round_timeout, estado.seconds_per_question * 1000)
      %{estado | round_index: nueva_ronda, timer_ref: ref}
    end
  end

  defp finalizar_partida(estado) do
    puntajes_finales =
      for {usuario, %{score: puntaje}} <- estado.players, into: %{}, do: {usuario, puntaje}

    ganador =
      puntajes_finales
      |> Enum.max_by(fn {_u, s} -> s end, fn -> {nil, 0} end)
      |> elem(0)

    Enum.each(puntajes_finales, fn {usuario, puntaje} ->
      UserManager.actualizar_puntaje_usuario(usuario, estado.topic, puntaje)
    end)

    # Notificar a los clientes sobre el fin de la partida
    GenServer.cast(Trivia.Server, {:difundir_a_partida, self(), {:fin_partida, ganador, puntajes_finales}})

    fecha =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.truncate(:second)
      |> NaiveDateTime.to_string()

    Trivia.Server.guardar_resultado(fecha, estado.topic, puntajes_finales)

    # Cancelar el temporizador si está activo
    if estado.timer_ref, do: Process.cancel_timer(estado.timer_ref)

    # Intentar eliminar la partida del supervisor
    case DynamicSupervisor.terminate_child(Trivia.Supervisor, self()) do
      :ok ->
        IO.puts("El proceso de la partida ha sido eliminado correctamente del supervisor.")
      {:error, :not_found} ->
        IO.puts("El proceso de la partida ya no está supervisado o no se encontró.")
    end

    # Asegurarse de que el proceso termine
    Process.exit(self(), :normal) # Esto termina el proceso de la partida de manera controlada.

    estado
  end
end
