import sys, os, numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "texgen"))
from noise import fbm, value_noise, _hash2

def fbm2d(size, period, octaves=4, seed=0):
    return fbm(size, period, octaves, seed)

def hash_noise(size, period, seed=0):
    ys, xs = np.mgrid[0:size, 0:size]
    return _hash2((xs * period // size) % period, (ys * period // size) % period, seed)
