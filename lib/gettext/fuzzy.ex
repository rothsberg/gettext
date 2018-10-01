defmodule Gettext.Fuzzy do
  @moduledoc false

  alias Gettext.PO
  alias Gettext.PO.Translation
  alias Gettext.PO.PluralTranslation

  @type translation_key :: binary | {binary, binary}

  @doc """
  Returns a matcher function that takes two translation keys and checks if they
  match.

  `String.jaro_distance/2` (which calculates the Jaro distance) is used to
  measure the distance between the two translations. `threshold` is the minimum
  distance that means a match. `{:match, distance}` is returned in case of a
  match, `:nomatch` otherwise.
  """
  @spec matcher(float) :: (translation_key, translation_key -> {:match, float} | :nomatch)
  def matcher(threshold) do
    fn old_key, new_key ->
      distance = jaro_distance(old_key, new_key)
      if distance >= threshold, do: {:match, distance}, else: :nomatch
    end
  end

  @doc """
  Finds the Jaro distance between the msgids of two translations.

  To mimic the behaviour of the `msgmerge` tool, this function only calculates
  the Jaro distance of the msgids of the two translations, even if one (or both)
  of them is a plural translation.
  """
  @spec jaro_distance(translation_key, translation_key) :: float
  def jaro_distance(key1, key2)

  # Apparently, msgmerge only looks at the msgid when performing fuzzy
  # matching. This means that if we have two plural translations with similar
  # msgids but very different msgid_plurals, they'll still fuzzy match.
  def jaro_distance({:regular, key1}, {:regular, key2}), do: String.jaro_distance(key1, key2)
  def jaro_distance({:plural, key1, _}, {:regular, key2}), do: String.jaro_distance(key1, key2)
  def jaro_distance({:regular, key1}, {:plural, key2, _}), do: String.jaro_distance(key1, key2)
  def jaro_distance({:plural, key1, _}, {:plural, key2, _}), do: String.jaro_distance(key1, key2)

  @doc """
  Merges a translation with the corresponding fuzzy match.

  `new` is the newest translation and `existing` is the existing translation
  that we use to populate the msgstr of the newest translation.

  Note that if `new` is a regular translation, then the result will be a regular
  translation; if `new` is a plural translation, then the result will be a
  plural translation.
  """
  @spec merge(PO.translation(), PO.translation()) :: PO.translation()
  def merge(new, existing) do
    # Everything comes from "new", except for the msgstr and the comments.
    new
    |> Map.put(:comments, existing.comments)
    |> merge_msgstr(existing)
    |> PO.Translations.mark_as_fuzzy()
  end

  defp merge_msgstr(%Translation{} = new, %Translation{} = existing),
    do: %{new | msgstr: existing.msgstr}

  defp merge_msgstr(%Translation{} = new, %PluralTranslation{} = existing),
    do: %{new | msgstr: existing.msgstr[0]}

  defp merge_msgstr(%PluralTranslation{} = new, %Translation{} = existing),
    do: %{new | msgstr: Map.new(new.msgstr, fn {i, _} -> {i, existing.msgstr} end)}

  defp merge_msgstr(%PluralTranslation{} = new, %PluralTranslation{} = existing),
    do: %{new | msgstr: existing.msgstr}
end
