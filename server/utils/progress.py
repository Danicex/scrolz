def no_progress(*args, **kwargs):
    """Used when nobody is watching (tests, running a function by hand).

    The real one is made in task/task.py and writes into Redis. Both are called like:
        progress("processing_pdf", "audio", chunk=2, total=5, msg="chunk_2", fraction=0.4)
    """
    return None
    