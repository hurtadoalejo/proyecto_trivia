defmodule Trivia.Supervisor do
  @moduledoc """
  DynamicSupervisor encargado de crear y monitorear las partidas activas.
  Cada partida es un proceso "Trivia.Game" que se ejecuta de forma independiente.
  """
  use DynamicSupervisor  # Importa el uso de DynamicSupervisor

  @doc """
    Inicia el DynamicSupervisor con un nombre global.
  """
  def start_link(_args) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
    Inicializa el DynamicSupervisor con la estrategia "one_for_one".
  """
  @impl true
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
    Inicia una nueva partida de trivia con las opciones dadas.
    Las opciones deben incluir:
      - tema: El tema de la trivia (string).
      - preguntas: Número de preguntas (integer).
      - tiempo: Tiempo por pregunta en segundos (integer).
  """
  def start_game(configuracion_partida) do
    child_config = {Trivia.Game, configuracion_partida}
    DynamicSupervisor.start_child(__MODULE__, child_config)
  end

  @doc """
    Devuelve la lista de partidas activas (procesos hijos).
  """
  def list_games do
    DynamicSupervisor.which_children(__MODULE__)
  end
end
