# nas_path_package

Helpers for locating Way Lab NAS mount points (`bandicoot`, `koala`) from notebooks and scripts, falling back to the enclosing Git repository's root directory when a mount isn't present.

## Install

If locally developing, install in editable mode:

```shell
pip install -e internal/nas_path_package
```

If not developing, install from github:

```shell
pip install git+https://github.com/WayScience/playbooks.git#subdirectory=internal/nas_path_package
```

## Usage

```python
from nas_path_package import init_notebook, nas_path_check

root_dir, in_notebook = init_notebook()
data_dir = nas_path_check(root_dir, nas_name="bandicoot")
```
