/* Problem C: */
#include <stdio.h>

int main() {
  int n, i;
  double sum, x;
  while (1==scanf("%d",&n) && n > 0) {
    for (i=0, sum = 0.0; i<n; ++i) {
      scanf("%lf",&x); sum += x;
    }
    printf("%.4lf\n", sum/n);
  }
  return 0;
}
