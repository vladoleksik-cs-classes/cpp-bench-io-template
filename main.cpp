#include <fstream>

using namespace std;

ifstream fin("input.txt");
ofstream fout("output.txt");

int main() {
  fout << "Hello World!" << endl;
  return 0;
}
