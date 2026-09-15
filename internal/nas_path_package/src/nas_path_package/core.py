"""Notebook initialization helpers and Bandicoot path utilities."""

from __future__ import annotations

import os
import pathlib
from typing import Tuple


def init_notebook() -> Tuple[pathlib.Path, bool]:
    """
    Initializes the notebook environment by determining the root directory of the Git repository
    and checking if the code is running in a Jupyter notebook.

    Returns
    -------
    Tuple[pathlib.Path, bool]
        - pathlib.Path: The root directory of the Git repository.
        - bool: True if running in a Jupyter notebook, False otherwise.
    """
    try:
        cfg = get_ipython().config
        in_notebook = True
    except NameError:
        in_notebook = False

    # Get the current working directory
    cwd = pathlib.Path.cwd()

    if (cwd / ".git").is_dir():
        root_dir = cwd

    else:
        root_dir = None
        for parent in cwd.parents:
            if (parent / ".git").is_dir():
                root_dir = parent
                break

    # Check if a Git root directory was found
    if root_dir is None:
        raise FileNotFoundError("No Git root directory found.")
    return root_dir, in_notebook


def nas_path_check(
    root_dir: pathlib.Path = init_notebook()[0],
    nas_name: str | None = None,
) -> pathlib.Path:
    """
    This function determines if the external mount point for Bandicoot exists.

    Parameters
    ----------
    root_dir : pathlib.Path, optional
        The root directory of the Git repository. Defaults to the result of init_notebook().
    nas_name : str | None, optional
        The name of the NAS mount point. If None, defaults to "bandicoot".

    Returns
    -------
    pathlib.Path
        The path to the Bandicoot mount point if it exists, otherwise the Git root directory.

    Notes
    -----
    - If nas_name is None, a warning is printed and the function defaults to the Git root directory.
    - If nas_name is not "bandicoot" or "koala", a warning is printed and the function defaults to the Git root directory.
    - If the specified NAS mount point does not exist, a warning is printed and the function defaults to the Git root directory.
    """
    if nas_name is None:
        print("Warning: nas_name is None. Defaulting to 'git root directory'.")
        return root_dir

    if nas_name not in ["bandicoot", "koala"]:
        print(f"Warning: nas_name must be either 'bandicoot' or 'koala'. Defaulting to 'git root directory'.")
        return root_dir

    if nas_name == "bandicoot":
        nas_path = pathlib.Path(os.path.expanduser("~/mnt/bandicoot")).resolve()
    else:
        nas_path = pathlib.Path(os.path.expanduser("~/mnt/koala")).resolve()

    if not nas_path.exists():
        # revert to the git root directory if the NAS mount point does not exist
        print(f"Warning: {nas_name} mount point does not exist. Reverting to the Git root directory.")
        return root_dir

    return nas_path
