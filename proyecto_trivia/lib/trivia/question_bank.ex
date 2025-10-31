defmodule GestorPreguntas do
  @archivo_preguntas "data/questions.csv"

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

  defp analizar_linea_pregunta(linea) do
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

  # Función para obtener UNA pregunta aleatoria por tema
  def obtener_pregunta_aleatoria_por_tema(tema_seleccionado) do
    todas_las_preguntas = cargar_preguntas()
    preguntas_del_tema = Enum.filter(todas_las_preguntas, fn pregunta ->
      pregunta.tema == tema_seleccionado end)

    case preguntas_del_tema do
  [] -> nil
  lista_preguntas ->
    lista_preguntas
    |> Enum.shuffle() # Mezcla el orden de los elementos de la lista aleatoriamente
    |> List.first() # Toma el primer elemento de la lista mezclada
    end
  end

  # Función para obtener diez preguntas aleatorias de un tema específico.
  def obtener_preguntas_aleatorias(tema) do
    cargar_preguntas()
    |> Enum.filter(fn pregunta -> pregunta.tema == tema end)
    |> Enum.shuffle()
    |> Enum.take(10)
  end

  # Función para obtener todos los temas disponibles
  def obtener_temas_disponibles do
    cargar_preguntas()
    |> Enum.map(fn pregunta -> pregunta.tema end)
    |> Enum.uniq()
  end
end
