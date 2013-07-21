#include <stdio.h>
#include <stdint.h>

#define SHR(x,n) ((x & 0xFFFFFFFF) >> n)
#define ROTR(x,n) (SHR(x,n) | (x << (32 - n)))
#define S0(x) (ROTR(x, 7) ^ ROTR(x,18) ^  SHR(x, 3))
#define S1(x) (ROTR(x,17) ^ ROTR(x,19) ^  SHR(x,10))
#define S2(x) (ROTR(x, 2) ^ ROTR(x,13) ^ ROTR(x,22))
#define S3(x) (ROTR(x, 6) ^ ROTR(x,11) ^ ROTR(x,25))
#define F0(x,y,z) ((x & y) | (z & (x | y)))
#define F1(x,y,z) (z ^ (x & (y ^ z)))

// SHA-256 constants (ROM)
uint32_t h0[8] = {0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19};
uint32_t k[64] = {0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
                  0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
                  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
                  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
                  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
                  0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
                  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
                  0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
                  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
                  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
                  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
                  0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
                  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
                  0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
                  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
                  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2};

// Test data
// Request: {"method": "getwork", "params": [], "id":0}
// Response: {"id":0,"error":null,"result":{"midstate":"7b4320166e8dc015684dab6321d775d7a05b94c1af16b4a43208e02c1ff75e63","target":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000","data":"0000000199c61d80e579e1c0ad76c808fddd6dc4e6eb6307be56d546000001cf00000000475a049ff4e4b6166c3c2b3220f5b6d780ade3043ac84e8a8400f4ed138d8d1e4e37a4e91a08e1e500000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000080020000","hash1":"00000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000010000"}}


uint32_t midstate[8] = {0x1620437b, 0x15c08d6e, 0x63ab4d68, 0xd775d721, 0xc1945ba0, 0xa4b416af, 0x2ce00832, 0x635ef71f}; // bytes reversed in each 32-bit word
uint32_t data[3] = {0x1e8d8d13, 0xe9a4374e, 0xe5e1081a}; // bytes reversed in each 32-bit word
uint32_t nonce = 0x195a2c52; // Golden nonces: 0x195a2c52, 0x5dcc535f, 0x7ab6a1f7

// padding (ROM) for each stage
uint32_t padding1[12] = {0x80000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000280};
uint32_t padding2[8] = {0x80000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000100};

int main( int argc, char *argv[] ) {
  uint32_t i;
  uint32_t w[64];
  uint32_t a, b, c, d, e, f, g, h;
  uint32_t t1, t2;

  uint32_t m1, m2, l, m1_new, m2_new, a_new, e_new;

  // first expander
  for (i = 0; i < 64; ++i) {
    if (i < 3) w[i] = data[i]; // this can be done on controller beforehand
    else if (i == 3) w[3] = nonce;
    else if (i < 16) w[i] = padding1[i-4];
    else w[i] = w[i-16] + S0(w[i-15]) + w[i-7] + S1(w[i-2]);
    printf("w[%02u] = %08x\n", i, w[i]);
  }

  for (i = 0; i < 67; ++i) {
    if ((i>0) && (i<65)) {
      m1_new = k[i-1] + w[i-1] + b + g;
      m2_new = k[i-1] + w[i-1] + g;
    } else {
      m1_new = 0;
      m2_new = 0;
    }

    if (i==0) {
      a_new = midstate[2];
    } else if (i==1) {
      a_new = midstate[1];
    } else if (i==2) {
      a_new = midstate[0];
    } else {
      a_new = F0(a, b, c) + S2(a) + l;
    }

    if (i==0) {
      b = midstate[3];
    } else {
      c = b;
      b = a;
    }

    a = a_new;

    if (i>1) {
      l = m2 + F1(e, f, g) + S3(e);
    }

    if (i==0) {
      e_new = midstate[5];
    } else if (i==1) {
      e_new = midstate[4];
    } else if (i<66) {
      e_new = m1 + F1(e, f, g) + S3(e);
    } else {
      e_new = 0;
    }

    if (i==0) {
      g = midstate[7];
      f = midstate[6];
    } else {
      g = f;
      f = e;
    }

    e = e_new;

    m1 = m1_new;
    m2 = m2_new;

    if (i>62) w[66-i] = a;
    if (i>61 && i<66) w[69-i] = e;

    printf("%02u %08x %08x %08x %08x %08x (%08x)\n", i, a, e, m1, m2, l, w[i]);

  }

  w[0] += midstate[0];
  w[1] += midstate[1];
  w[2] += midstate[2];
  w[3] += midstate[3];
  w[4] += midstate[4];
  w[5] += midstate[5];
  w[6] += midstate[6];
  w[7] += midstate[7];

  printf(" f %08x %08x %08x %08x %08x %08x %08x %08x\n", w[0], w[1], w[2], w[3], w[4], w[5], w[6], w[7]);

  // second expander
  for (i = 8; i < 64; ++i) {
    if (i < 16) w[i] = padding2[i-8];
    else w[i] = w[i-16] + S0(w[i-15]) + w[i-7] + S1(w[i-2]);
    printf("w[%02u] = %08x\n", i, w[i]);
  }

  for (i = 0; i < 67; ++i) {
    if ((i>0) && (i<65)) {
      m1_new = k[i-1] + w[i-1] + b + g;
      m2_new = k[i-1] + w[i-1] + g;
    } else {
      m1_new = 0;
      m2_new = 0;
    }

    if (i==0) {
      a_new = h0[2];
    } else if (i==1) {
      a_new = h0[1];
    } else if (i==2) {
      a_new = h0[0];
    } else {
      a_new = F0(a, b, c) + S2(a) + l;
    }

    if (i==0) {
      b = h0[3];
    } else {
      c = b;
      b = a;
    }

    a = a_new;

    if (i>1) {
      l = m2 + F1(e, f, g) + S3(e);
    }

    if (i==0) {
      e_new = h0[5];
    } else if (i==1) {
      e_new = h0[4];
    } else if (i<66) {
      e_new = m1 + F1(e, f, g) + S3(e);
    } else {
      e_new = 0;
    }

    if (i==0) {
      g = h0[7];
      f = h0[6];
    } else {
      g = f;
      f = e;
    }

    e = e_new;

    m1 = m1_new;
    m2 = m2_new;

    if (i>62) w[66-i] = a;
    if (i>61 && i<66) w[69-i] = e;

    printf("%02u %08x %08x %08x %08x %08x (%08x)\n", i, a, e, m1, m2, l, w[i]);

  }

  w[0] += h0[0];
  w[1] += h0[1];
  w[2] += h0[2];
  w[3] += h0[3];
  w[4] += h0[4];
  w[5] += h0[5];
  w[6] += h0[6];
  w[7] += h0[7];

  printf(" f %08x %08x %08x %08x %08x %08x %08x %08x\n", w[0], w[1], w[2], w[3], w[4], w[5], w[6], w[7]);
}
