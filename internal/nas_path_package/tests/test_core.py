import pathlib

import pytest

from nas_path_package.core import init_notebook, nas_path_check


def test_init_notebook_finds_git_root_at_cwd(tmp_path, monkeypatch):
    (tmp_path / ".git").mkdir()
    monkeypatch.chdir(tmp_path)

    root_dir, in_notebook = init_notebook()

    assert root_dir == tmp_path
    assert in_notebook is False


def test_init_notebook_finds_git_root_in_parent(tmp_path, monkeypatch):
    (tmp_path / ".git").mkdir()
    nested = tmp_path / "a" / "b"
    nested.mkdir(parents=True)
    monkeypatch.chdir(nested)

    root_dir, in_notebook = init_notebook()

    assert root_dir == tmp_path


def test_init_notebook_raises_without_git_root(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)

    with pytest.raises(FileNotFoundError):
        init_notebook()


def test_nas_path_check_defaults_to_root_when_nas_name_none(tmp_path, capsys):
    result = nas_path_check(root_dir=tmp_path, nas_name=None)

    assert result == tmp_path
    assert "Warning" in capsys.readouterr().out


def test_nas_path_check_defaults_to_root_when_nas_name_invalid(tmp_path, capsys):
    result = nas_path_check(root_dir=tmp_path, nas_name="not-a-real-nas")

    assert result == tmp_path
    assert "Warning" in capsys.readouterr().out


@pytest.mark.parametrize("nas_name", ["bandicoot", "koala"])
def test_nas_path_check_returns_mount_when_it_exists(tmp_path, monkeypatch, nas_name):
    monkeypatch.setattr(pathlib.Path, "exists", lambda self: True)

    result = nas_path_check(root_dir=tmp_path, nas_name=nas_name)

    assert result == pathlib.Path(f"~/mnt/{nas_name}").expanduser().resolve()


@pytest.mark.parametrize("nas_name", ["bandicoot", "koala"])
def test_nas_path_check_falls_back_to_root_when_mount_missing(
    tmp_path, monkeypatch, capsys, nas_name
):
    monkeypatch.setattr(pathlib.Path, "exists", lambda self: False)

    result = nas_path_check(root_dir=tmp_path, nas_name=nas_name)

    assert result == tmp_path
    assert "Warning" in capsys.readouterr().out
