# ==========================================================
# MÓDULO: UserManager
# Descripción general:
#   Este módulo gestiona el registro y consulta de usuarios
#   de un sistema de trivia. Permite registrar nuevos jugadores,
#   consultar su puntaje, buscar por ID y listar todos los jugadores.
#   Los datos se guardan en el archivo "data/user_data.txt"
# ==========================================================

defmodule UserManager do
  # Archivo donde se almacenan los datos de los usuarios
  @documento "data/users.csv"

  # ==========================================================
  # FUNCIÓN PRINCIPAL: main/0
  # Descripción:
  #   Muestra un menú con opciones para el usuario
  #   y ejecuta la funcionalidad seleccionada.
  # ==========================================================
  def main do
    # Solicita una opción al usuario
    numero = numero()

    # Evalúa la opción ingresada y ejecuta la acción correspondiente
    case numero do
      1 ->
        # Opción 1: Buscar jugador por ID
        buscar_por_id(mapeo(@documento), buscar_id())

      2 ->
        # Opción 2: Consultar puntaje de un jugador por su ID
        consultar_puntaje(mapeo(@documento), buscar_id())

      3 ->
        # Opción 3: Registrar un nuevo usuario
        registrar_usuario()

      4 ->
        # Opción 4: Mostrar todos los jugadores activos
        mapeo(@documento)

      _ ->
        # Si se ingresa un número no válido
        IO.inspect({:error, " NUMERO NO INDICADO"})
    end
  end

  # ==========================================================
  # FUNCIÓN: numero/0
  # Descripción:
  #   Muestra el menú principal de opciones y retorna
  #   la opción seleccionada convertida a número entero.
  # ==========================================================
  def numero() do
    IO.gets(
      "1 buscar por id, 2 consultar puntaje y 3 para registar , 4 para todos los jugadoes activos "
    )
    |> String.trim()
    |> String.to_integer()
  end

  # ==========================================================
  # SECCIÓN: REGISTRO DE USUARIOS
  # ==========================================================

  # FUNCIÓN: datos_usuario/0
  # Descripción:
  #   Solicita al usuario ingresar su nombre y contraseña.
  #   Devuelve un mapa con esos datos y el puntaje inicial en "0".
  def datos_usuario do
    IO.puts("--------- REGISTRO DE USUARIO -----------")

    # Se pide el nombre del usuario
    nombre = IO.gets("Nombre del usuario a registra: ") |> String.trim()

    # Se pide la contraseña
    contrasena = IO.gets("Contraseña del usuario: ") |> String.trim()

    # Se retorna un mapa con los datos
    %{nombre: nombre, contrasena: contrasena, score: "0"}
  end

  # FUNCIÓN: registrar_usuario/0
  # Descripción:
  #   Toma los datos del nuevo usuario y los guarda en el archivo de texto.
  #   Cada registro se almacena en una línea con formato CSV:
  #   nombre,contraseña,score
  def registrar_usuario() do
    # Se obtienen los datos del usuario ingresados por consola
    %{nombre: nombre, contrasena: contrasena, score: score} = datos_usuario()

    # Se construye la línea de texto que se escribirá en el archivo
    agregar_usuario = "#{nombre},#{contrasena},#{score}\n"

    # Se escribe la información en el archivo (modo append: agregar al final)
    case File.write(@documento, agregar_usuario, [:append]) do
      :ok ->
        "usuario agregado en #{@documento}"
    end
  end

  # ==========================================================
  # SECCIÓN: CONSULTA DE PUNTAJE
  # ==========================================================

  # FUNCIÓN: consultar_puntaje/2
  # Descripción:
  #   Busca un jugador por su ID en la lista de usuarios
  #   y muestra su puntaje en pantalla.
  # Parámetros:
  #   users -> lista de usuarios (mapas)
  #   id    -> número de identificación a buscar
  def consultar_puntaje(users, id) do
    case Enum.find(users, fn x -> x.id == id end) do
      nil ->
        # Si no se encuentra el usuario, se retorna un error
        {:error, " Usuario no encontrado"}

      usuario ->
        # Si el usuario existe, se muestra su puntaje
        IO.puts("El puntaje del jugador #{usuario.nombre} es de #{usuario.score}")
    end
  end

  # ==========================================================
  # SECCIÓN: BÚSQUEDA POR ID
  # ==========================================================

  # FUNCIÓN: buscar_id/0
  # Descripción:
  #   Pide al usuario ingresar un ID por consola y lo convierte a entero.
  def buscar_id do
    IO.gets("id a buscar: ")
    |> String.trim()
    |> String.to_integer()
  end

  # FUNCIÓN: buscar_por_id/2
  # Descripción:
  #   Busca un jugador dentro de la lista de usuarios por su ID
  #   y muestra su información completa.
  def buscar_por_id(users, id) do
    users
    |> Enum.find(fn x -> x.id == id end)
    |> IO.inspect()
  end

  # ==========================================================
  # SECCIÓN: MAPEO DE USUARIOS (LECTURA DEL ARCHIVO)
  # ==========================================================

  # FUNCIÓN: mapeo/1
  # Descripción:
  #   Lee el archivo donde están los usuarios registrados
  #   y convierte cada línea en un mapa con sus respectivos datos.
  def mapeo(@documento) do
    File.stream!(@documento)
    |> Enum.map(&(convertir_linea(&1)))
    |> IO.inspect(label: "---------JUGADORES ACTIVOS----------")
  end

  # FUNCIÓN: convertir_linea/1
  # Descripción:
  #   Convierte una línea del archivo (en formato CSV)
  #   a un mapa con los campos: nombre, id y score.
  # Ejemplo de línea:
  #   "Carlos,1,100"
  # Resultado:
  #   %{nombre: "Carlos", id: 1, score: 100}
  def convertir_linea(linea) do
    [nombre, id, score] = String.trim(linea) |>String.split(",")
    %{nombre: nombre, id: String.to_integer(id), score: String.to_integer(score)}
  end
end

# ==========================================================
# EJECUCIÓN DEL PROGRAMA
# Descripción:
#   Al cargar el archivo, se ejecuta automáticamente la función main().
# ==========================================================
UserManager.main()
