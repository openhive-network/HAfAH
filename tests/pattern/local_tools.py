class LCG:
    def __init__( self, seed=1, modulo=0x7FFFFFFF ):
        self.state = seed
        self.modulo = modulo

    def random(self):
        self.state = (self.state * 1103515245 + 12345) % self.modulo
        return self.state