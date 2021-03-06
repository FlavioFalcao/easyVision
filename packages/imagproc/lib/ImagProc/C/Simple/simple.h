int getPoints32f(float * pSrc, int sstep, int sr1, int sr2, int sc1, int sc2,
                 int max, int* tot, int* hp);

int lbp8u(int delta, unsigned char * pSrc, int sstep, int sr1, int sr2, int sc1, int sc2, int* histogram);

int hsvcodeTest(int kb, int kg, int kw,
                unsigned char * pSrc, int sstep,
                int sr1, int sr2, int sc1, int sc2);
int hsvcode(int kb, int kg, int kw,
            unsigned char * pSrc, int sstep,
            unsigned char * pDst, int dstep,
            int sr1, int sr2, int sc1, int sc2);

int localMaxScale3(float * pSrc1, int sstep1,
               float * pSrc2, int sstep2,
               float * pSrc3, int sstep3,
               int sr1, int sr2, int sc1, int sc2,
               int max, int* tot, float thres, int* hp);

int localMaxScale3Simplified
              (float * pSrc1, int sstep1,
               float * pSrc2, int sstep2,
               float * pSrc3, int sstep3,
               int sr1, int sr2, int sc1, int sc2,
               int max, int* tot, float thres, int* hp);

double csum32f(float * pSrc, int sstep, int sr1, int sr2, int sc1, int sc2);

int histodir(float * pSrc1, int sstep1,
             float * pSrc2, int sstep2,
             float * pSrc3, int sstep3,
             int sr1, int sr2, int sc1, int sc2,
             double sigma, int rm, int cm,
             int n, double* histogram);
