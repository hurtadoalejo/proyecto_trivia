defmodule QuestionManager do
  @preguntas "data/questions.csv"

  def load_questions do
    @preguntas
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.drop(1)
    |> Enum.map(&parse_question_line/1)
  end

  defp parse_question_line(line) do
    [tema, pregunta, r1, r2, r3, r4, correcta] =
      String.split(line, ",", trim: true)

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
      correcta: correcta
    }
  end
end
