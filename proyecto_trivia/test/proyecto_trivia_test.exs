defmodule ProyectoTriviaTest do
  use ExUnit.Case, async: true

  alias UserManager

  defmodule ManejoArchivos do
    @ruta_csv "data/users.csv"
    @ruta_copia "data/users.csv.bak"
    @encabezado "usuario;clave;Biología;Física;Historia;Matemáticas;Química\n"

    # Limpia el archivo CSV, escribiendo solo el encabezado.
    def limpiar_csv do
      File.write!(@ruta_csv, @encabezado)
    end

    # Crea una copia de seguridad del archivo CSV o lo crea si no existe.
    def crear_copia do
      if File.exists?(@ruta_csv) do
        File.cp!(@ruta_csv, @ruta_copia)
      else
        File.write!(@ruta_csv, @encabezado)
      end
    end

    # Restaura el archivo CSV desde la copia de seguridad, si existe.
    def restaurar_original do
      cond do
        File.exists?(@ruta_copia) ->
          File.cp!(@ruta_copia, @ruta_csv)
          File.rm!(@ruta_copia)

        true ->
          File.write!(@ruta_csv, @encabezado)
      end
    end
  end

  # Setup de prueba: crear copia antes de las pruebas y restaurar después.
  setup_all do
    ManejoArchivos.crear_copia()
    on_exit(fn -> ManejoArchivos.restaurar_original() end)
    :ok
  end

  # Setup de prueba: limpiar el archivo CSV antes de cada prueba.
  setup do
    ManejoArchivos.limpiar_csv()
    :ok
  end

  # ========== PRUEBA 1: Registro de usuarios ==========

  test "PRUEBA 1: Registro y verificación de usuarios" do
    IO.puts("\nPRUEBA 1: Registro y verificación de usuarios")

    # Registro de usuario
    assert :ok = UserManager.registrar_usuario("Juan", "clave123")

    # Consultar usuario y verificar propiedades
    usuario = UserManager.obtener_usuario("Juan")
    assert usuario != nil
    assert Map.get(usuario, :usuario) == "Juan"
    assert Map.get(usuario, :clave) == "clave123"

    # Verificar puntajes iniciales
    puntajes = Map.get(usuario, :puntajes)
    assert puntajes["matematicas"] == 0
    assert puntajes["historia"] == 0
    assert puntajes["biologia"] == 0

    # Intentar registrar usuario duplicado
    assert :error = UserManager.registrar_usuario("Juan", "clave123")

    IO.puts("PRUEBA 1 COMPLETADA")
  end

  # ========== PRUEBA 2: Consulta de puntajes individuales ==========

  test "PRUEBA 2: Consulta de puntajes individuales" do
    IO.puts("\nPRUEBA 2: Consulta de puntajes individuales")

    # Registro y consulta de puntajes
    assert :ok = UserManager.registrar_usuario("Carlos", "clave789")
    assert {:ok, "Carlos", 0} = UserManager.consultar_puntaje_total("Carlos")

    # Actualización de puntajes
    {:ok, _} = UserManager.actualizar_puntaje_usuario("Carlos", "matematicas", 10)
    {:ok, _} = UserManager.actualizar_puntaje_usuario("Carlos", "historia", 5)
    assert {:ok, "Carlos", 15} = UserManager.consultar_puntaje_total("Carlos")

    # Puntaje por tema
    assert :ok = UserManager.registrar_usuario("Ana", "clave101")
    assert {:ok, "Ana", 0} = UserManager.consultar_puntaje_tema("Ana", "matematicas")
    {:ok, _} = UserManager.actualizar_puntaje_usuario("Ana", "matematicas", 25)
    assert {:ok, "Ana", 25} = UserManager.consultar_puntaje_tema("Ana", "matematicas")

    IO.puts("PRUEBA 2 COMPLETADA")
  end

  # ========== PRUEBA 3: Actualización de puntajes ==========

  test "PRUEBA 3: Actualización y persistencia de puntajes" do
    IO.puts("\nPRUEBA 3: Actualización y persistencia de puntajes")

    # Registro y actualización de puntajes
    assert :ok = UserManager.registrar_usuario("Luis", "clave202")
    {:ok, usuario_actualizado} = UserManager.actualizar_puntaje_usuario("Luis", "biologia", 30)
    assert Map.get(usuario_actualizado, :puntajes)["biologia"] == 30

    # Verificación de suma acumulativa
    {:ok, usuario_actualizado2} = UserManager.actualizar_puntaje_usuario("Luis", "biologia", 15)
    assert Map.get(usuario_actualizado2, :puntajes)["biologia"] == 45

    # Persistencia de datos
    :ok = UserManager.registrar_usuario("UsuarioPersistente", "clave123")
    {:ok, _} = UserManager.actualizar_puntaje_usuario("UsuarioPersistente", "matematicas", 100)
    usuario = UserManager.obtener_usuario("UsuarioPersistente")
    assert Map.get(usuario, :puntajes)["matematicas"] == 100

    IO.puts("PRUEBA 3 COMPLETADA")
  end

  # ========== PRUEBA 4: Ranking global ==========

  test "PRUEBA 4: Ranking global de usuarios" do
    IO.puts("\nPRUEBA 4: Ranking global de usuarios")

    # Registro de usuarios y asignación de puntajes
    :ok = UserManager.registrar_usuario("Usuario1", "clave1")
    :ok = UserManager.registrar_usuario("Usuario2", "clave2")
    :ok = UserManager.registrar_usuario("Usuario3", "clave3")
    {:ok, _} = UserManager.actualizar_puntaje_usuario("Usuario1", "matematicas", 50)
    {:ok, _} = UserManager.actualizar_puntaje_usuario("Usuario2", "historia", 30)
    {:ok, _} = UserManager.actualizar_puntaje_usuario("Usuario3", "biologia", 70)

    # Consultar y verificar ranking
    ranking = UserManager.consultar_puntajes()
    assert "Usuario3" == elem(hd(ranking), 0)
    assert elem(hd(ranking), 1) == 70

    IO.puts("PRUEBA 4 COMPLETADA")
  end

  # ========== PRUEBA 5: Ranking por tema específico ==========

  test "PRUEBA 5: Ranking por tema específico" do
    IO.puts("\nPRUEBA 5: Ranking por tema específico")

    # Registro de estudiantes y asignación de puntajes
    :ok = UserManager.registrar_usuario("EstudianteA", "claveA")
    :ok = UserManager.registrar_usuario("EstudianteB", "claveB")
    :ok = UserManager.registrar_usuario("EstudianteC", "claveC")
    {:ok, _} = UserManager.actualizar_puntaje_usuario("EstudianteA", "matematicas", 40)
    {:ok, _} = UserManager.actualizar_puntaje_usuario("EstudianteB", "matematicas", 60)
    {:ok, _} = UserManager.actualizar_puntaje_usuario("EstudianteC", "matematicas", 25)

    # Consultar ranking de matemáticas
    ranking_matematicas = UserManager.consultar_puntajes_tema("matematicas")
    assert {"EstudianteB", 60} in ranking_matematicas

    # Consultar ranking de historia
    ranking_historia = UserManager.consultar_puntajes_tema("historia")
    assert {"EstudianteA", 0} in ranking_historia

    IO.puts("PRUEBA 5 COMPLETADA")
  end

  # ========== PRUEBA ADICIONAL: Manejo de errores ==========

  test "PRUEBA 6: Manejo de errores y casos borde" do
    IO.puts("PRUEBA 6: Manejo de errores y casos borde")

    assert {:error, "Usuario no encontrado."} = UserManager.consultar_puntaje_total("UsuarioInexistente")
    assert {:error, "Usuario no encontrado."} = UserManager.consultar_puntaje_tema("UsuarioInexistente", "matematicas")
    assert {:error, "Usuario no encontrado."} = UserManager.actualizar_puntaje_usuario("UsuarioInexistente", "matematicas", 10)

    IO.puts("PRUEBA 6 COMPLETADA: Manejo de errores funcionando correctamente")
  end
end
