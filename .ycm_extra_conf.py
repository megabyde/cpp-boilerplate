import os
import ycm_core
import sys
import json
from difflib import SequenceMatcher as SM


def DirectoryOfThisScript():
    return os.path.dirname(os.path.abspath(__file__))


def DatabaseFilePath():
    path = os.getcwd()
    while path != os.sep:
        # check if in-source build
        if os.path.exists(os.path.join(path, 'compile_commands.json')):
            return path
        path = os.path.dirname(path)

    path = DirectoryOfThisScript()
    if os.path.exists(os.path.join(path, 'compile_commands.json')):
        return path

    return None


def MakeRelativePathsInFlagsAbsolute(flags, working_directory):
    if not working_directory:
        return list(flags)
    new_flags = []
    make_next_absolute = False
    path_flags = ['-isystem', '-I', '-iquote', '--sysroot=']
    for flag in flags:
        new_flag = flag

        if make_next_absolute:
            make_next_absolute = False
            if not flag.startswith('/'):
                new_flag = os.path.join(working_directory, flag)

        for path_flag in path_flags:
            if flag == path_flag:
                make_next_absolute = True
                break

            if flag.startswith(path_flag):
                path = flag[len(path_flag):]
                new_flag = path_flag + os.path.join(working_directory, path)
                break

        if new_flag:
            new_flags.append(new_flag)
    return new_flags


def GetCompilationInfoForFile(database_path, filename):
    database = ycm_core.CompilationDatabase(database_path)
    # The compilation_commands.json file does not have entries for header files.
    # So we do a fuzzy search for flags for a corresponding source file, if any.
    # If one exists, the flags for that file should be good enough.
    with open(os.path.join(database_path, 'compile_commands.json')) as f:
        commands = json.load(f)
        scores = []
        for d in commands:
            path = d['file']
            score = SM(None, path, filename).ratio()
            scores.append((score, path))
        scores.sort()
        filename = scores[-1][1]
    return database.GetCompilationInfoForFile(filename)


def FlagsForFile(filename, **kwargs):
    database_path = DatabaseFilePath()
    if database_path:
        compilation_info = GetCompilationInfoForFile(database_path, filename)
        if not compilation_info:
            return None

        final_flags = MakeRelativePathsInFlagsAbsolute(
            compilation_info.compiler_flags_,
            compilation_info.compiler_working_dir_)
    else:
        final_flags = []

    return {
        'flags': final_flags,
        'do_cache': True
    }
