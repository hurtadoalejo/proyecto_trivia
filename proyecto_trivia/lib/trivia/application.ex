defmodule Trivia.Application do
  use Application
  @nodo_server :servidor@localhost
  @cookie :cookie

  def start(_type, _args) do
    ensure_node_started!(@nodo_server, :shortnames)
    Node.set_cookie(@cookie)

    children = [
      {Trivia.Server, name: Trivia.Server},
      {Trivia.Supervisor, []}
    ]

    res = Supervisor.start_link(children, strategy: :one_for_one, name: Trivia.MainSupervisor)

    IO.puts("""
    Servidor Trivia iniciado
    Nodo:   #{inspect(node())}
    Cookie: #{inspect(:erlang.get_cookie())}
    Proc:   #{inspect(Process.whereis(Trivia.Server))}
    """)

    res
  end

  defp ensure_node_started!(name, name_type) do
    unless Node.alive?() do
      case :net_kernel.start([name, name_type]) do
        {:ok, _} -> :ok
        {:error, {:already_started, _}} -> :ok
        other -> IO.puts("⚠️  No se pudo iniciar el nodo distribuido: #{inspect(other)}")
      end
    end
  end
end
