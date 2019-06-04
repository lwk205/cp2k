#!/usr/bin/env python

from __future__ import absolute_import

import unittest
import os
import tempfile
import shutil
import sys

from prettify import main
from prettify_cp2k import selftest

class TestSingleFileFolder(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.mkdtemp()
        self.fname = os.path.join(self.tempdir, "prettify_selftest.F")

        # create temporary file with example code
        with open(self.fname, "w") as fhandle:
            fhandle.write(selftest.content)

    def tearDown(self):
        shutil.rmtree(self.tempdir)

    def test_prettify(self):

        # call prettify, the return value should be 0 (OK)
        self.assertEqual(main([sys.argv[0], self.fname]), 0)

        # check if file was altered (it shouldn't)
        with open(self.fname) as fhandle:
            result = fhandle.read()

        self.assertEqual(result.splitlines(), selftest.content.splitlines())

if __name__ == '__main__':
    unittest.main()
