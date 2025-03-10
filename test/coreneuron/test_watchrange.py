# Basically want to test that net_move statement doesn't get
# mixed up with other instances.
import os
import pytest
import traceback

enable_gpu = bool(os.environ.get("CORENRN_ENABLE_GPU", ""))


from neuron import h

h.load_file("stdrun.hoc")

pc = h.ParallelContext()
h.steps_per_ms = 8
h.dt = 1.0 / h.steps_per_ms


class Cell:
    def __init__(self, gid):
        self.soma = h.Section(name="soma", cell=self)
        self.gid = gid
        pc.set_gid2node(gid, pc.id())
        self.r = h.Random()
        self.r.Random123(gid, 0, 0)
        self.syn = h.Bounce(self.soma(0.5))
        pc.cell(gid, h.NetCon(self.soma(0.5)._ref_v, None, sec=self.soma))
        self.syn.noiseFromRandom123(gid, 0, 1)
        self.t1vec = h.Vector()
        self.t1vec.record(self.syn._ref_t1, sec=self.soma)
        self.xvec = h.Vector()
        self.xvec.record(self.syn._ref_x, sec=self.soma)
        self.rvec = h.Vector()
        self.rvec.record(self.syn._ref_r, sec=self.soma)

    def result(self):
        return (
            self.syn.n_high,
            self.syn.n_mid,
            self.syn.n_low,
            self.t1vec.c(),
            self.xvec.c(),
            self.rvec.c(),
        )


def test_watchrange():
    from neuron import coreneuron

    coreneuron.enable = False

    ncell = 10
    gids = range(pc.id(), ncell, pc.nhost())  # round robin

    cells = [Cell(gid) for gid in gids]

    # @olupton changed from 20 to trigger assert(datum==2) failure.
    tstop = 1.0

    def run(tstop, mode):
        pc.set_maxstep(10)
        h.finitialize(-65)
        if mode == 0:
            pc.psolve(tstop)
        elif mode == 1:
            while h.t < tstop:
                pc.psolve(h.t + h.dt)
        else:
            while h.t < tstop:
                h.continuerun(h.t + h.dt)
                pc.psolve(h.t + h.dt)

    tvec = h.Vector()
    tvec.record(h._ref_t, sec=cells[0].soma)
    run(tstop, 0)  # NEURON run
    tvec = tvec.c()  # don't record again but save.

    stdlist = [cell.result() for cell in cells]

    print("CoreNEURON run")
    h.CVode().cache_efficient(1)
    coreneuron.enable = True
    coreneuron.verbose = 0
    coreneuron.gpu = bool(os.environ.get("CORENRN_ENABLE_GPU", ""))

    def runassert(mode):
        run(tstop, mode)
        hml = ["invalid", "low", " mid", " high"]
        for i, cell in enumerate(cells):
            result = cell.result()
            std = stdlist[i]
            for j in range(3):
                if std[j] != result[j]:
                    print(
                        "cell=%d %s:(%d %d) mode=%d"
                        % (i, hml[j], std[j], result[j], mode)
                    )
                    if not std[4].eq(result[4]):
                        k = int(std[4].c().sub(result[4]).indwhere("!=", 0))
                        print(
                            "first difference at %d (%g, %s, r=%g) vs (%g, %s, r=%g)"
                            % (
                                k,
                                std[3][k],
                                hml[int(std[4][k])],
                                std[5][k],
                                result[3][k],
                                hml[int(result[4][k])],
                                result[5][k],
                            )
                        )
                        for ik in range(k + 1):
                            print(
                                "  %d %g (%g, %s, r=%g) vs (%g, %s, r=%g)"
                                % (
                                    ik,
                                    tvec[ik],
                                    std[3][ik],
                                    hml[int(std[4][ik])],
                                    std[5][ik],
                                    result[3][ik],
                                    hml[int(result[4][ik])],
                                    result[5][ik],
                                )
                            )

                assert std[j] == result[j]
            for j in range(3, 6):
                pass
                assert std[j].eq(result[j])

    for mode in [0, 1, 2]:
        print("mode=", mode)
        runassert(mode)

    coreneuron.enable = False
    # teardown
    pc.gid_clear()
    return stdlist, tvec


if __name__ == "__main__":
    try:
        from neuron import gui

        stdlist, tvec = test_watchrange()
        g = h.Graph()
        print("n_high  n_mid  n_low")
        for i, result in enumerate(stdlist):
            print(result[0], result[1], result[2])
            result[4].line(g, tvec, i, 2)
        g.exec_menu("View = plot")
    except:
        traceback.print_exc()
        # Make the CTest test fail
        sys.exit(42)
    # The test doesn't exit without this.
    if enable_gpu:
        h.quit()
