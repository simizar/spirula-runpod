#!/usr/bin/env python3
"""Restore runtime credentials without printing their contents."""
import base64
import os
import pathlib
import pwd
import tempfile


def restore(home, workspace, uid, gid, encoded):
    # Fail closed on symlinks instead of following paths on an attached volume.
    directory = workspace / '.private'
    config_dir = directory / 'rclone'
    home_config = home / '.config'
    for path in (directory, config_dir, home_config):
        if path.is_symlink():
            raise ValueError('unsafe configuration directory')
        path.mkdir(mode=0o700, exist_ok=True)
        os.chown(path, uid, gid)
        if path != home_config:
            path.chmod(0o700)
    target = config_dir / 'rclone.conf'
    link = home_config / 'rclone'
    if target.is_symlink() or (target.exists() and not target.is_file()):
        raise ValueError('unsafe configuration file')
    if link.is_symlink():
        if link.resolve() != config_dir.resolve():
            raise ValueError('unexpected rclone symlink')
    elif link.exists():
        # Preserve a pre-existing home config; migrate explicitly rather than overwrite.
        raise ValueError('existing home rclone directory; migrate it before startup')
    if not target.exists() and encoded:
        data = base64.b64decode(encoded, validate=True)
        if not data:
            raise ValueError('empty configuration')
        fd, temporary = tempfile.mkstemp(dir=config_dir, prefix='.restore-')
        try:
            with os.fdopen(fd, 'wb') as output:
                output.write(data)
                os.fchown(output.fileno(), uid, gid)
            os.replace(temporary, target)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
    if target.exists():
        os.chown(target, uid, gid)
        target.chmod(0o600)
    if not link.is_symlink():
        link.symlink_to(config_dir, target_is_directory=True)


if __name__ == '__main__':
    try:
        user = pwd.getpwnam('studio')
        restore(pathlib.Path(user.pw_dir), pathlib.Path('/workspace'),
                user.pw_uid, user.pw_gid, os.environ.get('RCLONE_CONF_B64', ''))
    except Exception:
        # Exceptions from parsers can contain input: never print exception details.
        raise SystemExit('rclone setup failed; check paths and secret format (details hidden)')
