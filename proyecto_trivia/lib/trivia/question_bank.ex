defmodule GestorPreguntas do
  @archivo_preguntas "data/questions.csv"

  @doc """
  Función para cargar las preguntas desde el archivo CSV.
  Devuelve una lista de mapas con los datos de cada pregunta.
  """
  def cargar_preguntas do
    if File.exists?(@archivo_preguntas) do
      File.stream!(@archivo_preguntas)
      |> Stream.drop(1)
      |> Stream.map(&analizar_linea_pregunta/1)
      |> Enum.to_list()
    else
      IO.puts("El archivo de preguntas no existe.")
    end
  end

  @doc """
  Función para analizar una línea del archivo CSV y devolver un mapa con los datos de la pregunta.
  7 campos esperados: tema, pregunta, r1, r2, r3, r4, respuesta_correcta
  """
  def analizar_linea_pregunta(linea) do
    [tema, pregunta, r1, r2, r3, r4, respuesta_correcta] =
      String.trim(linea) |> String.split(";")

    respuestas = [
      "a) #{r1}",
      "b) #{r2}",
      "c) #{r3}",
      "d) #{r4}"
    ]

    %{
      tema: tema,
      pregunta: pregunta,
      respuestas: respuestas,
      respuesta_correcta: respuesta_correcta
    }
  end

  @doc """
  Función para obtener múltiples preguntas aleatorias por tema
  Limita la cantidad máxima de preguntas a 10.
  """
  def obtener_preguntas_aleatorias(tema, cantidad_preguntas) do
    if cantidad_preguntas <= 10 do
      cargar_preguntas()
      |> Enum.filter(fn pregunta -> pregunta.tema == tema end)
      |> Enum.shuffle()
      |> Enum.take(cantidad_preguntas)
    else
      {:error, "La cantidad máxima de preguntas es 10."}
    end
  end
end
