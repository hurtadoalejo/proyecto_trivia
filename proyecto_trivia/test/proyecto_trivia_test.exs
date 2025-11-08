defmodule ProyectoTriviaTest do
  use ExUnit.Case, async: false

  alias UserManager

  # --- Helpers de prueba ---
  defmodule Helpers do
    @csv_path "data/users.csv"
    @backup_path "data/users.csv.bak"
    @header "usuario;clave;Biología;Historia;Matemáticas;Química\n"

    def ensure_dir! do
      File.mkdir_p!("data")
    end

    def reset_csv! do
      ensure_dir!()
      File.write!(@csv_path, @header)
    end

    def backup_original! do
      ensure_dir!()
      if File.exists?(@csv_path) do
        File.cp!(@csv_path, @backup_path)
      else
        File.write!(@csv_path, @header)
      end
    end

    def restore_original! do
      cond do
        File.exists?(@backup_path) ->
          File.cp!(@backup_path, @csv_path)
          File.rm!(@backup_path)

        true ->
          File.write!(@csv_path, @header)
      end
    end
  end

  setup_all do
    Helpers.backup_original!()
    on_exit(fn -> Helpers.restore_original!() end)
    :ok
  end

  setup do
    Helpers.reset_csv!()
    :ok
  end

  # ========== PRUEBA 1: Registro de usuarios ==========

  test "PRUEBA 1: Registro y verificación de usuarios" do
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("🎯 PRUEBA 1: Registro y verificación de usuarios")
    IO.puts(String.duplicate("=", 60))

    IO.puts("📝 Registrando usuario 'Juan'...")
    assert :ok = UserManager.registrar_usuario("Juan", "clave123")
    IO.puts("✅ Usuario 'Juan' registrado exitosamente")

    IO.puts("🔍 Obteniendo usuario 'Juan'...")
    usuario = UserManager.obtener_usuario("Juan")
    IO.puts("✅ Usuario obtenido correctamente")

    IO.puts("📊 Verificando propiedades del usuario...")
    assert usuario != nil
    assert usuario != :error
    assert Map.get(usuario, :usuario) == "Juan"
    assert Map.get(usuario, :clave) == "clave123"
    IO.puts("✅ Propiedades del usuario verificadas")

    IO.puts("🎯 Verificando puntajes iniciales...")
    puntajes = Map.get(usuario, :puntajes)
    assert puntajes["matematicas"] == 0
    assert puntajes["historia"] == 0
    assert puntajes["biologia"] == 0
    IO.puts("✅ Puntajes iniciales correctos (todos en 0)")

    IO.puts("🚫 Probando registro duplicado...")
    assert :error = UserManager.registrar_usuario("Juan", "clave123")
    IO.puts("✅ Correctamente evitó registro duplicado")

    IO.puts("🏁 PRUEBA 1 COMPLETADA: Registro de usuarios funcionando correctamente")
  end

  # ========== PRUEBA 2: Consulta de puntajes individuales ==========

  test "PRUEBA 2: Consulta de puntajes individuales" do
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("🎯 PRUEBA 2: Consulta de puntajes individuales")
    IO.puts(String.duplicate("=", 60))

    IO.puts("📝 Registrando usuario 'Carlos'...")
    :ok = UserManager.registrar_usuario("Carlos", "clave789")
    IO.puts("✅ Usuario registrado")

    IO.puts("📊 Consultando puntaje total inicial...")
    assert {:ok, "Carlos", 0} = UserManager.consultar_puntaje_total("Carlos")
    IO.puts("✅ Puntaje total inicial correcto: 0")

    IO.puts("🔼 Actualizando puntajes...")
    {:ok, _} = UserManager.actualizar_puntaje_usuario("Carlos", "matematicas", 10)
    {:ok, _} = UserManager.actualizar_puntaje_usuario("Carlos", "historia", 5)
    IO.puts("✅ Puntajes actualizados: +10 en matemáticas, +5 en historia")

    IO.puts("📊 Verificando puntaje total actualizado...")
    assert {:ok, "Carlos", 15} = UserManager.consultar_puntaje_total("Carlos")
    IO.puts("✅ Puntaje total correcto: 15")

    IO.puts("📝 Registrando usuario 'Ana' para prueba por tema...")
    :ok = UserManager.registrar_usuario("Ana", "clave101")
    IO.puts("✅ Usuario 'Ana' registrado")

    IO.puts("🎯 Consultando puntaje por tema específico...")
    assert {:ok, "Ana", 0} = UserManager.consultar_puntaje_tema("Ana", "matematicas")
    IO.puts("✅ Puntaje inicial en matemáticas: 0")

    IO.puts("🔼 Actualizando puntaje de 'Ana' en matemáticas...")
    {:ok, _} = UserManager.actualizar_puntaje_usuario("Ana", "matematicas", 25)
    IO.puts("✅ Puntaje actualizado: +25 en matemáticas")

    IO.puts("🎯 Verificando puntajes por tema...")
    assert {:ok, "Ana", 25} = UserManager.consultar_puntaje_tema("Ana", "matematicas")
    assert {:ok, "Ana", 0} = UserManager.consultar_puntaje_tema("Ana", "historia")
    IO.puts("✅ Puntajes por tema correctos: Matemáticas=25, Historia=0")

    IO.puts("🏁 PRUEBA 2 COMPLETADA: Consulta de puntajes funcionando correctamente")
  end

  # ========== PRUEBA 3: Actualización de puntajes ==========

  test "PRUEBA 3: Actualización y persistencia de puntajes" do
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("🎯 PRUEBA 3: Actualización y persistencia de puntajes")
    IO.puts(String.duplicate("=", 60))

    IO.puts("📝 Registrando usuario 'Luis'...")
    :ok = UserManager.registrar_usuario("Luis", "clave202")
    IO.puts("✅ Usuario registrado")

    IO.puts("🔼 Actualizando puntaje en biología...")
    assert {:ok, usuario_actualizado} = UserManager.actualizar_puntaje_usuario("Luis", "biologia", 30)
    IO.puts("✅ Puntaje actualizado: +30 en biología")

    IO.puts("🔍 Verificando actualización...")
    assert Map.get(usuario_actualizado, :usuario) == "Luis"
    puntajes = Map.get(usuario_actualizado, :puntajes)
    assert puntajes["biologia"] == 30
    IO.puts("✅ Actualización verificada: Biología=30")

    IO.puts("➕ Sumando más puntos a biología...")
    assert {:ok, usuario_actualizado2} = UserManager.actualizar_puntaje_usuario("Luis", "biologia", 15)
    IO.puts("✅ Puntos sumados: +15 en biología")

    IO.puts("🔍 Verificando suma acumulativa...")
    puntajes_actualizados = Map.get(usuario_actualizado2, :puntajes)
    assert puntajes_actualizados["biologia"] == 45
    IO.puts("✅ Suma acumulativa correcta: 30 + 15 = 45")

    IO.puts("💾 Probando persistencia de datos...")
    :ok = UserManager.registrar_usuario("UsuarioPersistente", "clave123")
    {:ok, _} = UserManager.actualizar_puntaje_usuario("UsuarioPersistente", "matematicas", 100)

    usuario = UserManager.obtener_usuario("UsuarioPersistente")
    assert usuario != nil
    puntajes_persistentes = Map.get(usuario, :puntajes)
    assert puntajes_persistentes["matematicas"] == 100
    IO.puts("✅ Persistencia verificada: Datos guardados correctamente")

    IO.puts("🏁 PRUEBA 3 COMPLETADA: Actualización de puntajes funcionando correctamente")
  end

  # ========== PRUEBA 4: Ranking global ==========

  test "PRUEBA 4: Ranking global de usuarios" do
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("🎯 PRUEBA 4: Ranking global de usuarios")
    IO.puts(String.duplicate("=", 60))

    IO.puts("👥 Registrando múltiples usuarios...")
    :ok = UserManager.registrar_usuario("Usuario1", "clave1")
    :ok = UserManager.registrar_usuario("Usuario2", "clave2")
    :ok = UserManager.registrar_usuario("Usuario3", "clave3")
    IO.puts("✅ 3 usuarios registrados")

    IO.puts("🏆 Asignando puntajes diferentes...")
    {:ok, _} = UserManager.actualizar_puntaje_usuario("Usuario1", "matematicas", 50)
    {:ok, _} = UserManager.actualizar_puntaje_usuario("Usuario2", "historia", 30)
    {:ok, _} = UserManager.actualizar_puntaje_usuario("Usuario3", "biologia", 70)
    IO.puts("✅ Puntajes asignados: Usuario1=50, Usuario2=30, Usuario3=70")

    IO.puts("📈 Consultando ranking global...")
    ranking = UserManager.consultar_puntajes()
    IO.puts("✅ Ranking obtenido")

    IO.puts("🔍 Verificando estructura del ranking...")
    assert is_list(ranking)
    IO.puts("✅ Ranking es una lista")

    IO.puts("👤 Verificando usuarios en ranking...")
    usuarios_ranking = Enum.map(ranking, fn {usuario, _puntaje} -> usuario end)
    assert "Usuario1" in usuarios_ranking
    assert "Usuario2" in usuarios_ranking
    assert "Usuario3" in usuarios_ranking
    IO.puts("✅ Todos los usuarios están en el ranking")

    IO.puts("📊 Verificando orden descendente...")
    [{primer_usuario, primer_puntaje} | _] = ranking
    assert primer_usuario == "Usuario3"
    assert primer_puntaje == 70
    IO.puts("✅ Orden correcto: Usuario3 (70 puntos) en primer lugar")

    IO.puts("🏆 Mostrando ranking completo:")
    Enum.each(ranking, fn {usuario, puntaje} ->
      IO.puts("   #{usuario}: #{puntaje} puntos")
    end)

    IO.puts("🏁 PRUEBA 4 COMPLETADA: Ranking global funcionando correctamente")
  end

  # ========== PRUEBA 5: Ranking por tema específico ==========

  test "PRUEBA 5: Ranking por tema específico" do
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("🎯 PRUEBA 5: Ranking por tema específico")
    IO.puts(String.duplicate("=", 60))

    IO.puts("👥 Registrando estudiantes...")
    :ok = UserManager.registrar_usuario("EstudianteA", "claveA")
    :ok = UserManager.registrar_usuario("EstudianteB", "claveB")
    :ok = UserManager.registrar_usuario("EstudianteC", "claveC")
    IO.puts("✅ 3 estudiantes registrados")

    IO.puts("🔢 Asignando puntajes en matemáticas...")
    {:ok, _} = UserManager.actualizar_puntaje_usuario("EstudianteA", "matematicas", 40)
    {:ok, _} = UserManager.actualizar_puntaje_usuario("EstudianteB", "matematicas", 60)
    {:ok, _} = UserManager.actualizar_puntaje_usuario("EstudianteC", "matematicas", 25)
    IO.puts("✅ Puntajes en matemáticas asignados: A=40, B=60, C=25")

    IO.puts("📚 Asignando puntaje en historia (para comparación)...")
    {:ok, _} = UserManager.actualizar_puntaje_usuario("EstudianteA", "historia", 80)
    IO.puts("✅ Puntaje en historia asignado: EstudianteA=80")

    IO.puts("🎯 Consultando ranking de matemáticas...")
    ranking_matematicas = UserManager.consultar_puntajes_tema("matematicas")
    IO.puts("✅ Ranking de matemáticas obtenido")

    IO.puts("🔍 Verificando ranking de matemáticas...")
    assert is_list(ranking_matematicas)
    assert {"EstudianteB", 60} in ranking_matematicas
    assert {"EstudianteA", 40} in ranking_matematicas
    assert {"EstudianteC", 25} in ranking_matematicas
    IO.puts("✅ Todos los estudiantes aparecen en ranking de matemáticas")

    IO.puts("📊 Verificando orden en matemáticas...")
    [{primer_estudiante, primer_puntaje} | _] = ranking_matematicas
    assert primer_estudiante == "EstudianteB"
    assert primer_puntaje == 60
    IO.puts("✅ Orden correcto en matemáticas: EstudianteB (60 puntos)")

    IO.puts("📚 Consultando ranking de historia...")
    ranking_historia = UserManager.consultar_puntajes_tema("historia")
    IO.puts("✅ Ranking de historia obtenido")

    IO.puts("🔍 Comparando rankings...")
    assert {"EstudianteA", 80} in ranking_historia
    assert {"EstudianteB", 0} in ranking_historia
    IO.puts("✅ Rankings separados correctamente: Historia no mezcla con Matemáticas")

    IO.puts("🏆 Mostrando rankings por tema:")
    IO.puts("   MATEMÁTICAS:")
    Enum.each(ranking_matematicas, fn {estudiante, puntaje} ->
      IO.puts("     #{estudiante}: #{puntaje} puntos")
    end)

    IO.puts("   HISTORIA:")
    Enum.each(ranking_historia, fn {estudiante, puntaje} ->
      IO.puts("     #{estudiante}: #{puntaje} puntos")
    end)

    IO.puts("🏁 PRUEBA 5 COMPLETADA: Ranking por tema funcionando correctamente")
  end

  # ========== PRUEBA ADICIONAL: Manejo de errores ==========

  test "PRUEBA 6: Manejo de errores y casos borde" do
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("🎯 PRUEBA 6: Manejo de errores y casos borde")
    IO.puts(String.duplicate("=", 60))

    IO.puts("🔍 Consultando usuario que no existe...")
    assert {:error, "Usuario no encontrado."} = UserManager.consultar_puntaje_total("UsuarioInexistente")
    IO.puts("✅ Correctamente manejó usuario inexistente en puntaje total")

    IO.puts("🔍 Consultando tema de usuario que no existe...")
    assert {:error, "Usuario no encontrado."} = UserManager.consultar_puntaje_tema("UsuarioInexistente", "matematicas")
    IO.puts("✅ Correctamente manejó usuario inexistente en puntaje por tema")

    IO.puts("🚫 Intentando actualizar usuario que no existe...")
    assert {:error, "Usuario no encontrado."} = UserManager.actualizar_puntaje_usuario("UsuarioInexistente", "matematicas", 10)
    IO.puts("✅ Correctamente manejó actualización de usuario inexistente")

    IO.puts("🏁 PRUEBA 6 COMPLETADA: Manejo de errores funcionando correctamente")
  end
end
