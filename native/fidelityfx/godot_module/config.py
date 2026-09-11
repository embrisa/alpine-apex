def can_build(env, platform):
    return platform == "windows" and env["d3d12"]


def configure(env):
    pass
