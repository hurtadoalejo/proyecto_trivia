defmodule User do
  @moduledoc """
    Estructura que representa un usuario.

    Contiene:
      - Nombre de usuario.
      - Clave del usuario.
      - Mapa sobre los puntajes de cada tema.
  """
  @enforce_keys [:usuario, :clave]
  defstruct [:usuario, :clave, puntajes:
    %{"Matemáticas" => 0,
    "Historia" => 0,
    "Biología" => 0,
    "Química" => 0}]
end

defmodule UserManager do
  @usuarios "data/users.csv" # Ruta del archivo CSV de usuarios
  @moduledoc """
  Módulo encargado de la gestión de usuarios.

  Permite:
    - Registrar nuevos usuarios.
    - Obtener usuarios existentes.
    - Consultar puntajes por tema de un usuario.
    - Consultar puntaje total de un usuario.
    - Actualizar usuarios.
  """

  @doc """
    Registra un nuevo usuario pidiendo datos por consola.
    Verifica que el nombre de usuario no exista previamente.
  """
  def registrar_usuario_consola() do
    usuario = ingresar_texto("Ingrese el nombre del usuario: ")
    clave = ingresar_texto("Ingrese la clave del usuario: ")
    case obtener_usuario(usuario) do
        nil ->
          inscribir_usuario_csv(%User{usuario: usuario, clave: clave})
          IO.puts("Usuario registrado exitosamente.")
        _ -> IO.puts("ERROR: El nombre de usuario ya existe.")
      end
  end

  @doc """
    Función auxiliar para ingresar texto desde la consola.
    Valida que el texto no esté vacío.
  """
  def ingresar_texto(mensaje) do
    entrada = IO.gets(mensaje)
    |> String.trim()
    case entrada do
      "" ->
        IO.puts("ERROR: El campo no puede estar vacio.")
        ingresar_texto(mensaje)
      _ -> entrada
    end
  end

  @doc """
    Función auxiliar para ingresar un tema desde la consola.
    Valida que el tema sea uno de los existentes.
  """
  def ingresar_tema(mensaje) do
    tema = ingresar_texto(mensaje)
    cond do
      tema in ["Matemáticas", "Historia", "Química", "Biología"] -> tema
      true ->
        IO.puts("ERROR: Tema inválido.")
        ingresar_tema(mensaje)
    end
  end

  @doc """
    Convierte una estructura de usuario en una línea de texto
    para ser almacenada en el archivo CSV.
  """
  def convertir_struct_linea(usuario) do
    nombre_usuario = usuario.usuario
    clave_usuario = usuario.clave
    puntajes_usuario = usuario.puntajes
    |> Enum.map(fn {materia, puntaje} -> "#{materia}:#{puntaje}" end)
    |> Enum.join(",")
    "#{nombre_usuario},#{clave_usuario},#{puntajes_usuario}\n"
  end

  @doc """
    Inscribe un nuevo usuario en el archivo CSV.
  """
  def inscribir_usuario_csv(usuario) do
    linea = convertir_struct_linea(usuario)
    File.write(@usuarios, "#{linea}", [:append])
  end

  @doc """
    Obtiene un usuario por su nombre de usuario.
  """
  def obtener_usuario(usuario) do
    File.stream!(@usuarios)
    |> Stream.map(fn linea -> convertir_linea_struct(linea) end)
    |> Enum.find(fn %User{usuario: usuario_temporal} -> usuario_temporal == usuario  end)
  end

  @doc """
    Obtiene un usuario pedido por consola y se muestra en consola.
    Si no se encuentra, retorna un mensaje de error.
  """
  def obtener_usuario_consola() do
    usuario = ingresar_texto("Ingrese el nombre del usuario a buscar: ")
    File.stream!(@usuarios)
    |> Stream.map(fn linea -> convertir_linea_struct(linea) end)
    |> Enum.find(fn %User{usuario: usuario_temporal} -> usuario_temporal == usuario  end)
    |> case do
      nil -> "ERROR: Usuario no encontrado."
      usuario -> usuario
    end
  end

  @doc """
    Convierte una línea de texto del archivo CSV en una estructura de usuario.
  """
  def convertir_linea_struct(linea) do
    [usuario, clave | puntajes] = String.trim(linea) |> String.split(",")
    puntajes_convertidos = Enum.reduce(puntajes, %{}, fn puntaje, acc ->
      [materia, score] = String.split(puntaje, ":")
      Map.put(acc, materia, String.to_integer(score))
    end)
    %User{usuario: usuario, clave: clave, puntajes: puntajes_convertidos}
  end

  @doc """
    Consulta el puntaje de un usuario pedido por consola en un tema específico.
    Muestra el puntaje o un mensaje de error si el usuario no existe.
  """
  def consultar_puntaje_consola() do
    usuario = ingresar_texto("Ingrese el nombre del usuario: ")
    tema = ingresar_tema("Ingrese el tema a consultar (Matemáticas, Historia, Biología, Química): ")
    case obtener_usuario(usuario) do
      nil -> IO.puts("ERROR: Usuario no encontrado.")
      usuario -> IO.puts("El puntaje de #{usuario.usuario} en #{tema} es #{Map.get(usuario.puntajes, tema)}")
    end
  end

  @doc """
    Consulta el puntaje total de un usuario pedido por consola sumando todos los temas.
    Muestra el puntaje total o un mensaje de error si el usuario no existe.
  """
  def consultar_puntaje_total_consola() do
    usuario = ingresar_texto("Ingrese el nombre del usuario: ")
    case obtener_usuario(usuario) do
      nil -> IO.puts("ERROR: Usuario no encontrado.")
      usuario ->
        total = Enum.reduce(usuario.puntajes, 0, fn {_tema, puntaje}, acc -> acc + puntaje end)
        IO.puts("El puntaje total de #{usuario.usuario} es #{total}")
    end
  end

  @doc """
    Actualiza la clave de un usuario pedido por consola.
    Muestra un mensaje de éxito o error si el usuario no existe.
  """
  def actualizar_clave_consola() do
    usuario = ingresar_texto("Ingrese el nombre del usuario a actualizar: ")
    case obtener_usuario(usuario) do
      nil -> IO.puts("ERROR: Usuario no encontrado.")
      usuario ->
        nueva_clave = ingresar_texto("Ingrese la nueva clave: ")
        usuario_actualizado = %User{usuario | clave: nueva_clave}
        actualizar_usuario_csv(usuario_actualizado)
        IO.puts("La clave del usuario ha sido actualizado.")
    end
  end

  @doc """
    Actualiza un usuario en el archivo CSV.
  """
  def actualizar_usuario_csv(usuario_actualizado) do
    usuarios = File.stream!(@usuarios)
    |> Stream.map(fn linea -> convertir_linea_struct(linea) end)
    |> Enum.map(fn usuario ->
      cond do
        usuario.usuario == usuario_actualizado.usuario -> usuario_actualizado
        true -> usuario
      end
    end)
    sobreescribir_usuarios(usuarios)
  end

  @doc """
    Sobreescribe el archivo CSV con la lista de usuarios proporcionada.
  """
  def sobreescribir_usuarios(usuarios) do
    contenido = Enum.map(usuarios, fn usuario ->
      convertir_struct_linea(usuario)
    end)

    File.write!(@usuarios, contenido)
  end
end
