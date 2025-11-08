defmodule Trivia.Application do
  @moduledoc """
  Punto de entrada de la aplicación Trivia.
  """
  use Application
  @nodo_server :servidor@localhost
  @cookie :cookie

  @doc """
  Inicia la aplicación Trivia.
  """
  def start(_type, _args) do
    asegurar_nodo_iniciado(@nodo_server, :shortnames)
    Node.set_cookie(@cookie)

    children = [
      {Trivia.Server, name: Trivia.Server},
      {Trivia.Supervisor, []}
    ]

    respuesta = Supervisor.start_link(children, strategy: :one_for_one, name: Trivia.MainSupervisor)

    IO.puts("""
    Servidor Trivia iniciado
    Nodo:   #{inspect(node())}
    Cookie: #{inspect(:erlang.get_cookie())}
    Proc:   #{inspect(Process.whereis(Trivia.Server))}
    """)

    respuesta
  end

  @doc """
  Asegura que el nodo distribuido esté iniciado.
  """
  def asegurar_nodo_iniciado(nombre, tipo_nombre) do
    unless Node.alive?() do
      case :net_kernel.start([nombre, tipo_nombre]) do
        {:ok, _} ->
          :ok
        {:error, {:already_started, _}} ->
          :ok
        otro ->
          IO.puts("No se pudo iniciar el nodo distribuido: #{inspect(otro)}")
      end
    end
  end
end
