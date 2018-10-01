defmodule Gettext.FuzzyTest do
  use ExUnit.Case, async: true

  alias Gettext.Fuzzy

  alias Gettext.PO.{
    Translation,
    ParticularTranslation,
    PluralTranslation,
    ParticularPluralTranslation
  }

  test "matcher/1" do
    assert Fuzzy.matcher(0.5).({:regular, "foo"}, {:regular, "foo"}) == {:match, 1.0}
    assert Fuzzy.matcher(0.5).({:regular, "foo"}, {:regular, "bar"}) == :nomatch
    assert Fuzzy.matcher(0.0).({:regular, "foo"}, {:regular, "bar"}) == {:match, 0.0}
  end

  test "jaro_distance/2" do
    assert Fuzzy.jaro_distance({:regular, "foo"}, {:regular, "foo"}) == 1.0
    assert Fuzzy.jaro_distance({:regular, "foo"}, {:particular, "a", "foo"}) == 1.0
    assert Fuzzy.jaro_distance({:regular, "foo"}, {:plural, "foo", "a"}) == 1.0
    assert Fuzzy.jaro_distance({:regular, "foo"}, {:particular_plural, "a", "foo", "b"}) == 1.0

    assert Fuzzy.jaro_distance({:regular, "foo"}, {:regular, "bar"}) == 0.0
    assert Fuzzy.jaro_distance({:regular, "foo"}, {:particular, "a", "bar"}) == 0.0
    assert Fuzzy.jaro_distance({:regular, "foo"}, {:plural, "bar", "a"}) == 0.0
    assert Fuzzy.jaro_distance({:regular, "foo"}, {:particular_plural, "a", "bar", "b"}) == 0.0

    assert Fuzzy.jaro_distance({:regular, "foo"}, {:regular, "foos"}) > 0.0
    assert Fuzzy.jaro_distance({:regular, "foo"}, {:particular, "a", "foos"}) > 0.0
    assert Fuzzy.jaro_distance({:regular, "foo"}, {:plural, "foos", "a"}) > 0.0
    assert Fuzzy.jaro_distance({:regular, "foo"}, {:particular_plural, "a", "foos", "b"}) > 0.0
  end

  describe "merge/2" do
    test "two regular translations" do
      t1 = %Translation{msgid: "foo"}
      t2 = %Translation{msgid: "foos", msgstr: "bar"}

      assert %Translation{} = t = Fuzzy.merge(t1, t2)

      assert t.msgid == "foo"
      assert t.msgstr == "bar"
      assert MapSet.member?(t.flags, "fuzzy")
    end

    test "a regular translation and a particular translation" do
      t1 = %Translation{msgid: "foo"}
      t2 = %ParticularTranslation{msgctxt: "ctxt", msgid: "foos", msgstr: "bar"}

      assert %Translation{} = t = Fuzzy.merge(t1, t2)

      assert t.msgid == "foo"
      assert t.msgstr == "bar"
      assert MapSet.member?(t.flags, "fuzzy")
    end

    test "a regular translation and a plural translation" do
      t1 = %Translation{msgid: "foo"}
      t2 = %PluralTranslation{msgid: "foos", msgid_plural: "bar", msgstr: %{0 => "a", 1 => "b"}}

      assert %Translation{} = t = Fuzzy.merge(t1, t2)

      assert t.msgid == "foo"
      assert t.msgstr == "a"
      assert MapSet.member?(t.flags, "fuzzy")
    end

    test "a regular translation and a particular plural translation" do
      t1 = %Translation{msgid: "foo"}

      t2 = %ParticularPluralTranslation{
        msgctxt: "ctxt",
        msgid: "foos",
        msgid_plural: "bar",
        msgstr: %{0 => "a", 1 => "b"}
      }

      assert %Translation{} = t = Fuzzy.merge(t1, t2)

      assert t.msgid == "foo"
      assert t.msgstr == "a"
      assert MapSet.member?(t.flags, "fuzzy")
    end

    # Particular
    test "two particular translations" do
      t1 = %ParticularTranslation{msgctxt: "ctxt1", msgid: "foo"}
      t2 = %ParticularTranslation{msgctxt: "ctxt2", msgid: "foos", msgstr: "bar"}

      assert %ParticularTranslation{} = t = Fuzzy.merge(t1, t2)

      assert t.msgctxt == "ctxt1"
      assert t.msgid == "foo"
      assert t.msgstr == "bar"
      assert MapSet.member?(t.flags, "fuzzy")
    end

    test "a particular translation and a regular translation" do
      t1 = %ParticularTranslation{msgctxt: "ctxt1", msgid: "foo"}
      t2 = %Translation{msgid: "foos", msgstr: "bar"}

      assert %ParticularTranslation{} = t = Fuzzy.merge(t1, t2)

      assert t.msgctxt == "ctxt1"
      assert t.msgid == "foo"
      assert t.msgstr == "bar"
      assert MapSet.member?(t.flags, "fuzzy")
    end

    test "a particular translation and a plural translation" do
      t1 = %ParticularTranslation{msgctxt: "ctxt1", msgid: "foo"}
      t2 = %PluralTranslation{msgid: "foos", msgid_plural: "bar", msgstr: %{0 => "a", 1 => "b"}}

      assert %ParticularTranslation{} = t = Fuzzy.merge(t1, t2)

      assert t.msgid == "foo"
      assert t.msgstr == "a"
      assert MapSet.member?(t.flags, "fuzzy")
    end

    test "a particular translation and a particular plural translation" do
      t1 = %ParticularTranslation{msgctxt: "ctxt1", msgid: "foo"}

      t2 = %ParticularPluralTranslation{
        msgctxt: "ctxt2",
        msgid: "foos",
        msgid_plural: "bar",
        msgstr: %{0 => "a", 1 => "b"}
      }

      assert %ParticularTranslation{} = t = Fuzzy.merge(t1, t2)

      assert t.msgctxt == "ctxt1"
      assert t.msgid == "foo"
      assert t.msgstr == "a"
      assert MapSet.member?(t.flags, "fuzzy")
    end

    # Plural
    test "a plural translation and a regular translation" do
      t1 = %PluralTranslation{msgid: "foo", msgid_plural: "bar", msgstr: %{0 => "", 1 => ""}}
      t2 = %Translation{msgid: "foos", msgstr: "bar"}

      assert %PluralTranslation{} = t = Fuzzy.merge(t1, t2)

      assert t.msgid == "foo"
      assert t.msgid_plural == "bar"
      assert t.msgstr == %{0 => "bar", 1 => "bar"}
      assert MapSet.member?(t.flags, "fuzzy")
    end

    test "a plural translation and a particular translation" do
      t1 = %PluralTranslation{msgid: "foo", msgid_plural: "bar", msgstr: %{0 => "", 1 => ""}}
      t2 = %ParticularTranslation{msgctxt: "ctxt2", msgid: "foos", msgstr: "bar"}

      assert %PluralTranslation{} = t = Fuzzy.merge(t1, t2)

      assert t.msgid == "foo"
      assert t.msgid_plural == "bar"
      assert t.msgstr == %{0 => "bar", 1 => "bar"}
      assert MapSet.member?(t.flags, "fuzzy")
    end

    test "two plural translations" do
      t1 = %PluralTranslation{msgid: "foo", msgid_plural: "bar"}
      t2 = %PluralTranslation{msgid: "foos", msgid_plural: "baz", msgstr: %{0 => "a", 1 => "b"}}

      assert %PluralTranslation{} = t = Fuzzy.merge(t1, t2)

      assert t.msgid == "foo"
      assert t.msgid_plural == "bar"
      assert t.msgstr == %{0 => "a", 1 => "b"}
      assert MapSet.member?(t.flags, "fuzzy")
    end

    test "a plural translation and a particular plural translation" do
      t1 = %PluralTranslation{msgid: "foo", msgid_plural: "bar"}

      t2 = %ParticularPluralTranslation{
        msgctxt: "ctxt",
        msgid: "foos",
        msgid_plural: "baz",
        msgstr: %{0 => "a", 1 => "b"}
      }

      assert %PluralTranslation{} = t = Fuzzy.merge(t1, t2)

      assert t.msgid == "foo"
      assert t.msgid_plural == "bar"
      assert t.msgstr == %{0 => "a", 1 => "b"}
      assert MapSet.member?(t.flags, "fuzzy")
    end

    # Particular Plural
    test "a particular plural translation and a regular translation" do
      t1 = %ParticularPluralTranslation{
        msgctxt: "ctxt1",
        msgid: "foo",
        msgid_plural: "bar",
        msgstr: %{0 => "", 1 => ""}
      }

      t2 = %Translation{msgid: "foos", msgstr: "bar"}

      assert %ParticularPluralTranslation{} = t = Fuzzy.merge(t1, t2)

      assert t.msgctxt == "ctxt1"
      assert t.msgid == "foo"
      assert t.msgid_plural == "bar"
      assert t.msgstr == %{0 => "bar", 1 => "bar"}
      assert MapSet.member?(t.flags, "fuzzy")
    end

    test "a particular plural translation and a particular translation" do
      t1 = %ParticularPluralTranslation{
        msgctxt: "ctxt1",
        msgid: "foo",
        msgid_plural: "bar",
        msgstr: %{0 => "", 1 => ""}
      }

      t2 = %ParticularTranslation{msgctxt: "ctxt2", msgid: "foos", msgstr: "bar"}

      assert %ParticularPluralTranslation{} = t = Fuzzy.merge(t1, t2)

      assert t.msgctxt == "ctxt1"
      assert t.msgid == "foo"
      assert t.msgid_plural == "bar"
      assert t.msgstr == %{0 => "bar", 1 => "bar"}
      assert MapSet.member?(t.flags, "fuzzy")
    end

    test "a particular plural translation and a plural translation" do
      t1 = %ParticularPluralTranslation{
        msgctxt: "ctxt1",
        msgid: "foo",
        msgid_plural: "bar",
        msgstr: %{0 => "", 1 => ""}
      }

      t2 = %PluralTranslation{msgid: "foos", msgid_plural: "baz", msgstr: %{0 => "a", 1 => "b"}}

      assert %ParticularPluralTranslation{} = t = Fuzzy.merge(t1, t2)

      assert t.msgctxt == "ctxt1"
      assert t.msgid == "foo"
      assert t.msgid_plural == "bar"
      assert t.msgstr == %{0 => "a", 1 => "b"}
      assert MapSet.member?(t.flags, "fuzzy")
    end

    test "two particular plural translations" do
      t1 = %ParticularPluralTranslation{
        msgctxt: "ctxt1",
        msgid: "foo",
        msgid_plural: "bar",
        msgstr: %{0 => "", 1 => ""}
      }

      t2 = %ParticularPluralTranslation{
        msgctxt: "ctxt2",
        msgid: "foos",
        msgid_plural: "baz",
        msgstr: %{0 => "a", 1 => "b"}
      }

      assert %ParticularPluralTranslation{} = t = Fuzzy.merge(t1, t2)

      assert t.msgctxt == "ctxt1"
      assert t.msgid == "foo"
      assert t.msgid_plural == "bar"
      assert t.msgstr == %{0 => "a", 1 => "b"}
      assert MapSet.member?(t.flags, "fuzzy")
    end
  end
end
