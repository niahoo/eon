defmodule EON do
  def from_file(filename), do: load_file(filename, false, nil)
  def from_file_unsafe(filename), do: load_file(filename, true, [])
  def from_file_unsafe(filename, bindings), do: load_file(filename, true, bindings)

  def load_file(filename, allow_unsafe, bindings) do
    {:ok, file} = File.read(filename)
    safe = check_if_safe(file)

    cond do
      allow_unsafe ->
        {contents, _results} = Code.eval_string(file, bindings)
        {:ok, Map.merge(%{}, contents)}
      safe ->
        {contents, _results} = Code.eval_string(file, [])
        {:ok, Map.merge(%{}, contents)}
      true ->
        {:error, "#{filename} contains unsafe data. Load with EON.from_file_unsafe to ignore this."}
    end
  end

  def to_file(map, filename) do
    map = Map.merge(%{}, map)
    contents =  Macro.to_string(quote do: unquote(map))
    {:ok, file} = File.open(filename, [:write])
    IO.binwrite(file, contents)

    {:ok, filename}
  end

  def check_if_safe(file) do
    {:ok, contents} = Code.string_to_quoted(file)
    elem(contents, 2)
    |> Enum.map(&is_safe?/1)
    |> List.flatten
    |> Enum.all?(&(&1))
  end

  def is_safe?(value) do
    case value do
      {_key, {expression, _line, value}} ->
        if expression != :{} and expression != :%{} do
          false
        else
          value
          |> Enum.filter(&(is_tuple(&1)))
          |> Enum.map(&is_safe?/1)
        end
      {_key, value} when is_list(value) ->
        only_tuples = value |> Enum.filter(&(is_tuple(&1)))
        results = only_tuples |> Enum.map(&is_safe?/1)
        Enum.all?(results, &(&1))
      {expression, _line, _value} ->
        expression == :{} or expression == :%{}
      _ ->
        true
    end
  end
end
