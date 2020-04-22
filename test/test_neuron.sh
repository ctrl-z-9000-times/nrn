# A simple set of tests checking if neuron is working correctly
set -e

python_exe="${1:-python}"

# download some mod files for testing nrnivmodl
[ -d testcorenrn ] ||  git clone https://github.com/nrnhines/testcorenrn.git

echo "PYTHON VERSION `python --version`"

# Test 1: run base tests for within python
$python_exe -c "import neuron; neuron.test(); neuron.test_rxd()"

# Test 2: execute nrniv
nrniv -c "print \"hello\""

# Test 3: execute nrnivmodl
rm -rf x86_64
nrnivmodl testcorenrn

# Test 4: run base tests for within python via special
./x86_64/special -python -c "import neuron; neuron.test(); neuron.test_rxd(); quit()"

# Test 5: execute nrniv
./x86_64/special -c "print \"hello\""

# Test 6: run demo
neurondemo -c 'demo(4)' -c 'run()' -c 'quit()'

# Test 7: multi-mpi test
echo "Testing MPI"

brew unlink openmpi
brew link mpich
/usr/local/opt/mpich/bin/mpirun -n 2 nrniv -python ./src/parallel/test0.py -mpi
/usr/local/opt/mpich/bin/mpirun -n 2 nrniv ./src/parallel/test0.hoc -mpi

brew unlink mpich
brew link openmpi
/usr/local/opt/openmpi/bin/mpirun -n 2 nrniv -python ./src/parallel/test0.py -mpi
/usr/local/opt/openmpi/bin/mpirun -n 2 nrniv ./src/parallel/test0.hoc -mpi
