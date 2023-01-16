#include "test.h"

typedef struct LoadStoreTestCase {
    Float f;
    UnpackedFloat u;
} LoadStoreTestCase;

static LoadStoreTestCase load_store_test_cases[] = {
    { { 0x00000000, 0 }, { 0x00000000, 1, POSITIVE } },
    { { 0x00000000, 127 }, { 0x80000000, 127, POSITIVE } },
    { { 0x7FFFFFFE, 157 }, { 0xFFFFFFFE, 157, POSITIVE } },
    { { 0x80000000, 158 }, { 0x80000000, 158, NEGATIVE } },
    { { 0x08442211, 127 }, { 0x88442211, 127, POSITIVE } },
    // Smallest possible normalized exponent
    { { 0x00000000, 1 }, { 0x80000000, 1, POSITIVE } },
    // Subnormal
    { { 0x00000400, 0 }, { 0x00000400, 1, POSITIVE } },
};

static void test_load_fpx(void) {
    Float value;
    LoadStoreTestCase* test_case;
    int i;

    PRINT_TEST_NAME();

    for (i = 0; i < sizeof load_store_test_cases / sizeof *load_store_test_cases; i++) {
        test_case = load_store_test_cases + i;
        fprintf(stderr, "  %s:%d: load_fpx(t=$%08X, e=$%02X)\n", __FILE__, __LINE__, 
                test_case->f.t, test_case->f.e);
        SET_FLOAT(value, test_case->f.e, test_case->f.t);
        load_fpx(&FP0, &value);
        ASSERT_FPX_EQ(FP0, test_case->u.s, test_case->u.e, test_case->u.t);
        load_fpx(&FP1, &value);
        ASSERT_FPX_EQ(FP1, test_case->u.s, test_case->u.e, test_case->u.t);
    }
}

static void test_store_fpx(void) {
    Float value;
    LoadStoreTestCase* test_case;
    int i;

    PRINT_TEST_NAME();

    for (i = 0; i < sizeof load_store_test_cases / sizeof *load_store_test_cases; i++) {
        test_case = load_store_test_cases + i;
        fprintf(stderr, "  %s:%d: store_fpx(t=$%08X, e=$%02X, s=$%02X)\n", __FILE__, __LINE__,
                test_case->u.t, test_case->u.e, test_case->u.s);
        SET_FPX(FP0, test_case->u.s, test_case->u.e, test_case->u.t);
        store_fpx(&FP0, &value);
        ASSERT_FLOAT_EQ(value, test_case->f.e, test_case->f.t);
        SET_FPX(FP1, test_case->u.s, test_case->u.e, test_case->u.t);
        store_fpx(&FP1, &value);
        ASSERT_FLOAT_EQ(value, test_case->f.e, test_case->f.t);
    }
}

static void test_swap_fp0_fp1(void) {
    PRINT_TEST_NAME();
    SET_FPX(FP0, POSITIVE, 2, 12345678L);
    SET_FPX(FP1, NEGATIVE, 1, 1418858818L);
    swap_fp0_fp1();
    ASSERT_FPX_EQ(FP0, NEGATIVE, 1, 1418858818L);
    ASSERT_FPX_EQ(FP1, POSITIVE, 2, 12345678L);
}

static void test_adjust_exponent(void) {
    PRINT_TEST_NAME();
    SET_FPX(FP0, POSITIVE, 0, 0);
    adjust_exponent(0, 0);
    ASSERT_FPX_EQ(FP0, POSITIVE, 0, 0);
    ASSERT_EQ(reg_c, 0);
    adjust_exponent(1, 0);
    ASSERT_FPX_EQ(FP0, POSITIVE, 1, 0);
    ASSERT_EQ(reg_c, 0);
    adjust_exponent(0, 1);
    ASSERT_FPX_EQ(FP0, POSITIVE, 0, 0);
    ASSERT_EQ(reg_c, 0);
    SET_FPX(FP0, POSITIVE, 192, 0);
    adjust_exponent(192, 0);
    ASSERT_FPX_EQ(FP0, POSITIVE, 128, 0);
    ASSERT_EQ(reg_c, 1);
    SET_FPX(FP0, POSITIVE, 0, 0);
    adjust_exponent(0, 192);
    ASSERT_FPX_EQ(FP0, POSITIVE, 64, 0);
    ASSERT_EQ(reg_c, 255);
}

static void call_normalize(char s, char e, unsigned long x, unsigned long t, char b,
                           char expect_e, unsigned long expect_t, int line) {
    char err;
    FP0s = s;
    FP0e = e;
    FP2 = x;
    FP0t = t;
    reg_b = b;
    fprintf(stderr, "  %s:%d: normalize(t=$%08LX%08LX e=%02X s=%02X grs=%02X)\n", __FILE__, line, x, t, e, s, b);
    err = normalize();
    ASSERT_EQ(err, 0);
    ASSERT_FLOAT_EQ(FP0, expect_e, expect_t);
}

static void test_normalize(void) {
    PRINT_TEST_NAME();

    // 0
    call_normalize(POSITIVE, 0, 0, 0, 0, 1, 0, __LINE__);
    // 0 significand with any exponent normalizes to 0
    call_normalize(POSITIVE, 127, 0, 0, 0, 1, 0, __LINE__);
    // 1
    call_normalize(POSITIVE, 127, 0x00, 0x00000001, 0x00, 96, 0x80000000, __LINE__);
    // -1
    call_normalize(NEGATIVE, 127, 0x00, 0x00000001, 0x00, 96, 0x80000000, __LINE__);
    // 32,767
    call_normalize(POSITIVE, 157, 0x00, 0x00007FFF, 0x00, 140, 0xFFFE0000, __LINE__);
    // 2,147,483,647
    call_normalize(POSITIVE, 158, 0x00, 0x7FFFFFFF, 0x00, 157, 0xFFFFFFFE, __LINE__);
    // -2,147,483,648
    call_normalize(NEGATIVE, 158, 0x00, 0x80000000, 0x00, 158, 0x80000000, __LINE__);
    // 2,286,166,545
    call_normalize(POSITIVE, 157, 0x00, 0x88442211, 0x00, 157, 0x88442211, __LINE__);
    // 4,294,967,296
    call_normalize(POSITIVE, 158, 0x01, 0x00000000, 0x00, 159, 0x80000000, __LINE__);
    // Subnormal
    call_normalize(POSITIVE, 9, 0x00, 0x00001234, 0x00, 1, 0x00123400, __LINE__);
    call_normalize(POSITIVE, 8, 0x00, 0x00001234, 0x00, 1, 0x00091A00, __LINE__);
}

typedef struct IntConversionTestCase {
    int value;
    UnpackedFloat u;
} IntConversionTestCase;

static IntConversionTestCase int_conversion_test_cases[] = {
    { 0, { 0x00000000, 1, POSITIVE } },
    { 1, { 0x80000000, 127, POSITIVE } },
    { 32767, { 0xFFFE0000, 141, POSITIVE } },
    { (int)-32768L, { 0x80000000, 142, NEGATIVE } },
    { 4112, { 0x80800000, 139, POSITIVE } },
};

static void test_int_to_fp(void) {
    IntConversionTestCase* test_case;
    int i;

    PRINT_TEST_NAME();

    for (i = 0; i < sizeof int_conversion_test_cases / sizeof *int_conversion_test_cases; i++) {
        test_case = int_conversion_test_cases + i;
        fprintf(stderr, "  %s:%d: int_to_fp(%d)\n", __FILE__, __LINE__, test_case->value);
        int_to_fp(test_case->value);
        ASSERT_FPX_EQ(FP0, test_case->u.s, test_case->u.e, test_case->u.t);
    }
}

static void test_truncate_fp_to_int(void) {
    IntConversionTestCase* test_case;
    int i;
    int value;

    PRINT_TEST_NAME();

    for (i = 0; i < sizeof int_conversion_test_cases / sizeof *int_conversion_test_cases; i++) {
        test_case = int_conversion_test_cases + i;
        fprintf(stderr, "  %s:%d: truncate_fp_to_int32(t=$%08LX e=%02X s=%02X)\n", __FILE__, __LINE__,
            test_case->u.t, test_case->u.e, test_case->u.s);
        SET_FPX(FP0, test_case->u.s, test_case->u.e, test_case->u.t);
        value = truncate_fp_to_int();
        ASSERT_EQ(carry_flag, 0);
        ASSERT_EQ(value, test_case->value);
    }
}

typedef struct Int32ConversionTestCase {
    unsigned long value;
    UnpackedFloat u;
} Int32ConversionTestCase;

static Int32ConversionTestCase int32_conversion_test_cases[] = {
    { 0, { 0x00000000, 1, POSITIVE } },
    { 1, { 0x80000000, 127, POSITIVE } },
    { 2147483647UL, { 0xFFFFFFFE, 157, POSITIVE } },
    { 2147483648UL, { 0x80000000, 158, POSITIVE } },
    { 4294967295UL, { 0xFFFFFFFF, 158, POSITIVE } },
    { 4112, { 0x80800000, 139, POSITIVE } },
};

static void test_int32_to_fp(void) {
    Int32ConversionTestCase* test_case;
    int i;

    PRINT_TEST_NAME();

    for (i = 0; i < sizeof int32_conversion_test_cases / sizeof *int32_conversion_test_cases; i++) {
        test_case = int32_conversion_test_cases + i;
        fprintf(stderr, "  %s:%d: int32_to_fp(%lu)\n", __FILE__, __LINE__, test_case->value);
        SET_FPX(FP0, POSITIVE, 0, test_case->value);
        int32_to_fp();
        ASSERT_FPX_EQ(FP0, test_case->u.s, test_case->u.e, test_case->u.t);
    }
}

static void test_truncate_fp_to_int32(void) {
    Int32ConversionTestCase* test_case;
    int i;
    char err;

    PRINT_TEST_NAME();

    for (i = 0; i < sizeof int32_conversion_test_cases / sizeof *int32_conversion_test_cases; i++) {
        test_case = int32_conversion_test_cases + i;
        fprintf(stderr, "  %s:%d: truncate_fp_to_int32(t=$%08LX e=%02X s=%02X)\n", __FILE__, __LINE__,
            test_case->u.t, test_case->u.e, test_case->u.s);
        SET_FPX(FP0, test_case->u.s, test_case->u.e, test_case->u.t);
        err = truncate_fp_to_int32();
        ASSERT_EQ(err, 0);
        ASSERT_EQ(FP0t, test_case->value);
    }
}

#define CALL_FP(f, s_0, e_0, t_0, s_1, e_1, t_1, expect_s, expect_e, expect_t) \
            call_fp(#f, f, s_0, e_0, t_0, s_1, e_1, t_1, expect_s, expect_e, expect_t, __LINE__)

static void call_fp(const char* f_name, char (*f)(void), char s_0, char e_0, unsigned long t_0,
                    char s_1, char e_1, unsigned long t_1,
                    char expect_s, char expect_e, unsigned long expect_t, int line) {
    char err;
    SET_FPX(FP0, s_0, e_0, t_0);
    SET_FPX(FP1, s_1, e_1, t_1);
    fprintf(stderr, "  %s:%d: %s(t=%08LX e=%02X s=%02X, t=%08LX e=%02X s=%02X)\n", __FILE__, line, f_name,
            t_0, e_0, s_0, t_1, e_1, s_1);
    err = f();
    ASSERT_EQ(err, 0);
    ASSERT_FPX_EQ(FP0, expect_s, expect_e, expect_t);
}

static void test_fadd(void) {
    PRINT_TEST_NAME();

    // 0 + 0
    CALL_FP(fadd, POSITIVE, 1, 0, POSITIVE, 1, 0, POSITIVE, 1, 0);
    // 1 + 1
    CALL_FP(fadd, POSITIVE, 127, 0x80000000, POSITIVE, 127, 0x80000000, POSITIVE, 128, 0x80000000);
    // 0.5 + 0.5
    CALL_FP(fadd, POSITIVE, 126, 0x80000000, POSITIVE, 126, 0x80000000, POSITIVE, 127, 0x80000000);
    // -1 + (-1
    CALL_FP(fadd, NEGATIVE, 127, 0x80000000, NEGATIVE, 127, 0x80000000, NEGATIVE, 128, 0x80000000);
    // 1 + (-1)
    CALL_FP(fadd, POSITIVE, 127, 0x80000000, NEGATIVE, 127, 0x80000000, POSITIVE, 1, 0);
    // -2 + 1
    CALL_FP(fadd, NEGATIVE, 128, 0x80000000, POSITIVE, 127, 0x80000000, NEGATIVE, 127, 0x80000000);
    // 1 + (-2)
    CALL_FP(fadd, POSITIVE, 127, 0x80000000, NEGATIVE, 128, 0x80000000, NEGATIVE, 127, 0x80000000);
    // -1 + 2
    CALL_FP(fadd, NEGATIVE, 127, 0x80000000, POSITIVE, 128, 0x80000000, POSITIVE, 127, 0x80000000);
    // 2 + (-1)
    CALL_FP(fadd, POSITIVE, 128, 0x80000000, NEGATIVE, 127, 0x80000000, POSITIVE, 127, 0x80000000);
    // 1 + 0.0001220703125
    CALL_FP(fadd, POSITIVE, 127, 0x80000000, POSITIVE, 114, 0x80000000, POSITIVE, 127, 0x80040000);
    // 1 + 3.14159
    CALL_FP(fadd, POSITIVE, 127, 0x80000000, POSITIVE, 128, 0xC90FCF81, POSITIVE, 129, 0x8487E7C1);
    // 1 + 0.00000000046566128730
    CALL_FP(fadd, POSITIVE, 127, 0x80000000, POSITIVE, 96, 0x80000000, POSITIVE, 127, 0x80000001);
    // 1 + 0.00000000011641532182 (should round down)
    CALL_FP(fadd, POSITIVE, 127, 0x80000000, POSITIVE, 94, 0x80000000, POSITIVE, 127, 0x80000000);
    // 1 + 0.00000000023283064365 (should round up)
    CALL_FP(fadd, POSITIVE, 127, 0x80000000, POSITIVE, 95, 0x80000000, POSITIVE, 127, 0x80000001);
    // 1 + 0.00000000034924596547 (should round up)
    CALL_FP(fadd, POSITIVE, 127, 0x80000000, POSITIVE, 95, 0xC0000000, POSITIVE, 127, 0x80000001);
}

static void test_fsub(void) {
    PRINT_TEST_NAME();

    // fsub just delegates to fadd, so we just have to verify that the sign is changed correctly.

    // 0 - 0
    CALL_FP(fsub, POSITIVE, 1, 0, POSITIVE, 1, 0, POSITIVE, 1, 0);
    // 1 - 1
    CALL_FP(fsub, POSITIVE, 128, 0x80000000, POSITIVE, 128, 0x80000000, POSITIVE, 1, 0);
    // -1 - (-1)
    CALL_FP(fsub, NEGATIVE, 128, 0x80000000, NEGATIVE, 128, 0x80000000, POSITIVE, 1, 0);
    // 1 - (-1)
    CALL_FP(fsub, POSITIVE, 128, 0x80000000, NEGATIVE, 128, 0x80000000, POSITIVE, 129, 0x80000000);
}

static void test_fmul(void) {
    PRINT_TEST_NAME();

    // 0 * 0
    CALL_FP(fmul, POSITIVE, 0, 0, POSITIVE, 0, 0, POSITIVE, 0, 0);
    // 1 * 1
    CALL_FP(fmul, POSITIVE, 127, 0x80000000, POSITIVE, 127, 0x80000000, POSITIVE, 127, 0x80000000);
    // 1 * -1
    CALL_FP(fmul, POSITIVE, 127, 0x80000000, NEGATIVE, 127, 0x80000000, NEGATIVE, 127, 0x80000000);
    // -1 * 1
    CALL_FP(fmul, NEGATIVE, 127, 0x80000000, POSITIVE, 127, 0x80000000, NEGATIVE, 127, 0x80000000);
    // -1 * -1
    CALL_FP(fmul, NEGATIVE, 127, 0x80000000, NEGATIVE, 127, 0x80000000, POSITIVE, 127, 0x80000000);
    // 2 * 2
    CALL_FP(fmul, POSITIVE, 128, 0x80000000, POSITIVE, 128, 0x80000000, POSITIVE, 129, 0x80000000);
    // 0.5 * 0.5
    CALL_FP(fmul, POSITIVE, 126, 0x80000000, POSITIVE, 126, 0x80000000, POSITIVE, 125, 0x80000000);
    // 10 * 10
    CALL_FP(fmul, POSITIVE, 130, 0xA0000000, POSITIVE, 130, 0xA0000000, POSITIVE, 133, 0xC8000000);
    // 100 * 10
    CALL_FP(fmul, POSITIVE, 133, 0xC8000000, POSITIVE, 130, 0xA0000000, POSITIVE, 136, 0xFA000000);
    // 1000 * 10
    CALL_FP(fmul, POSITIVE, 136, 0xFA000000, POSITIVE, 130, 0xA0000000, POSITIVE, 140, 0x9C400000);
    // 10000 * 10
    CALL_FP(fmul, POSITIVE, 140, 0x9C400000, POSITIVE, 130, 0xA0000000, POSITIVE, 143, 0xC3500000);
    // 3.14159 * 100000
    CALL_FP(fmul, POSITIVE, 128, 0xC90FCF81, POSITIVE, 143, 0xC3500000, POSITIVE, 145, 0x9965E000);
    // 2^-71 * 2^-71 (exponent -142 is out of range, adjust to -127)
    CALL_FP(fmul, POSITIVE, 56, 0x80000000, POSITIVE, 56, 0x80000000, POSITIVE, 1, 0x00008000);
}

static void test_fdiv(void) {
    PRINT_TEST_NAME();

    // 1 / 1
    CALL_FP(fdiv, POSITIVE, 127, 0x80000000, POSITIVE, 127, 0x80000000, POSITIVE, 127, 0x80000000);
    // 2 / 1
    CALL_FP(fdiv, POSITIVE, 128, 0x80000000, POSITIVE, 127, 0x80000000, POSITIVE, 128, 0x80000000);
    // 2 / 2
    CALL_FP(fdiv, POSITIVE, 128, 0x80000000, POSITIVE, 128, 0x80000000, POSITIVE, 127, 0x80000000);
    // 100 / 10
    CALL_FP(fdiv, POSITIVE, 133, 0xC8000000, POSITIVE, 130, 0xA0000000, POSITIVE, 130, 0xA0000000);
    // 1000 / 10
    CALL_FP(fdiv, POSITIVE, 136, 0xFA000000, POSITIVE, 130, 0xA0000000, POSITIVE, 133, 0xC8000000);
    // 10000 / 10
    CALL_FP(fdiv, POSITIVE, 140, 0x9C400000, POSITIVE, 130, 0xA0000000, POSITIVE, 136, 0xFA000000);
    // 100000 / 1
    CALL_FP(fdiv, POSITIVE, 143, 0xC3500000, POSITIVE, 130, 0xA0000000, POSITIVE, 140, 0x9C400000);
    // 314159 / 100000
    CALL_FP(fdiv, POSITIVE, 145, 0x9965E000, POSITIVE, 143, 0xC3500000, POSITIVE, 128, 0xC90FCF81);
}

static void call_fcmp(char s_0, char e_0, unsigned long t_0, char s_1, char e_1, unsigned long t_1,
                       int expect_result, int line) {
    int result;
    SET_FPX(FP0, s_0, e_0, t_0);
    SET_FPX(FP1, s_1, e_1, t_1);
    fprintf(stderr, "  %s:%d: fcmp(t=%08LX e=%02X s=%02X, t=%08LX e=%02X s=%02X)\n", __FILE__, line,
            t_0, e_0, s_0, t_1, e_1, s_1);
    result = fcmp();
    ASSERT_EQ(result, expect_result);
}

static void test_fcmp(void) {
    PRINT_TEST_NAME();

    // TODO: fix! Exponent for subnormal cases should be 1.
    // 0 <=> 0
    call_fcmp(POSITIVE, 0, 0, POSITIVE, 0, 0, 0, __LINE__);
    // 1 <=> 0
    call_fcmp(POSITIVE, 128, 0x80000000, POSITIVE, 0, 0, 1, __LINE__);
    // 0 <=> 1
    call_fcmp(POSITIVE, 0, 0, POSITIVE, 128, 0x80000000, -1, __LINE__);
    // 2 <=> 1
    call_fcmp(POSITIVE, 129, 0x80000000, POSITIVE, 128, 0x80000000, 1, __LINE__);
    // 1 <=> 2
    call_fcmp(POSITIVE, 128, 0x80000000, POSITIVE, 129, 0x80000000, -1, __LINE__);
    // 1+e <=> 1
    call_fcmp(POSITIVE, 128, 0x80000001, POSITIVE, 128, 0x80000000, 1, __LINE__);
    // 1 <=> 1+e
    call_fcmp(POSITIVE, 128, 0x80000000, POSITIVE, 128, 0x80000001, -1, __LINE__);
    // 2^126 <=> 1+e
    call_fcmp(POSITIVE, 254, 0x80000000, POSITIVE, 128, 0x80000001, 1, __LINE__);
    // 1+e <=> 2^126
    call_fcmp(POSITIVE, 128, 0x80000001, POSITIVE, 254, 0x80000000, -1, __LINE__);
}

static void test_char_to_digit(void) {
    char err;

    PRINT_TEST_NAME();

    err = char_to_digit('0');
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 0);
    err = char_to_digit('9');
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 9);
    err = char_to_digit('0'-1);
    ASSERT_NE(err, 0);
    err = char_to_digit('9'+1);
    ASSERT_NE(err, 0);
    err = char_to_digit(' ');
    ASSERT_NE(err, 0);
    err = char_to_digit('A');
    ASSERT_NE(err, 0);
    err = char_to_digit(0);
    ASSERT_NE(err, 0);
    err = char_to_digit(255);
    ASSERT_NE(err, 0);
}

static void call_fp_to_string(char s, char e, unsigned long t, const char* expect_string, int line) {
    fprintf(stderr, "  %s:%d: fp_to_string(t=$%08LX e=%02X s=%02X)\n", __FILE__, line, t, e, s);
    SET_FPX(FP0, s, e, t);
    bp = 0;
    fp_to_string();
    buffer[bp] = '\0';
    ASSERT_STRING_EQ(buffer, expect_string);
}

static void test_fp_to_string(void) {
    PRINT_TEST_NAME();

    // 0
    call_fp_to_string(POSITIVE, 0, 0x00000000, "0", __LINE__);
    // 1
    call_fp_to_string(POSITIVE, 127, 0x80000000, "1", __LINE__);
    // -1
    call_fp_to_string(NEGATIVE, 127, 0x80000000, "-1", __LINE__);
    // 10
    call_fp_to_string(POSITIVE, 130, 0xA0000000, "10", __LINE__);
    // 25
    call_fp_to_string(POSITIVE, 131, 0xC8000000, "25", __LINE__);
    // 100
    call_fp_to_string(POSITIVE, 133, 0xC8000000, "100", __LINE__);
    // -100
    call_fp_to_string(NEGATIVE, 133, 0xC8000000, "-100", __LINE__);
    // 3.14159
    call_fp_to_string(POSITIVE, 128, 0xC90FCF81, "3.14159", __LINE__);
    // 0.0314159
    call_fp_to_string(POSITIVE, 122, 0x80ADF571, "0.0314159", __LINE__);
    // 2,147,483,647
    call_fp_to_string(POSITIVE, 157, 0xFFFFFFFE, "2147483647", __LINE__);
    // -2,147,483,648
    call_fp_to_string(NEGATIVE, 158, 0x80000000, "-2147483648", __LINE__);
    // 2^36
    call_fp_to_string(POSITIVE, 163, 0x80000000, "6.87194767E10", __LINE__);
    // 2^-120
    call_fp_to_string(POSITIVE, 7, 0x80000000, "7.52316385E-37", __LINE__);

    // Exponent edge cases
    // +/- 1E9 should print without E
    // +/- 1E10 should print in scientific
    call_fp_to_string(POSITIVE, 156, 0xEE6B2800, "1000000000", __LINE__);
    call_fp_to_string(NEGATIVE, 156, 0xEE6B2800, "-1000000000", __LINE__);
    call_fp_to_string(POSITIVE, 160, 0x9502F900, "1E10", __LINE__);
    call_fp_to_string(NEGATIVE, 160, 0x9502F900, "-1E10", __LINE__);
}

static void call_string_to_fp(const char* string, char expect_s, char expect_e, unsigned long expect_t, int line) {
    char err;
    fprintf(stderr, "  %s:%d: string_to_fp(\"%s\")\n", __FILE__, line, string);
    strcpy(buffer, string);
    bp = 0;
    err = string_to_fp();
    ASSERT_EQ(err, 0);
    ASSERT_FPX_EQ(FP0, expect_s, expect_e, expect_t);
}

static void fail_string_to_fp(const char* string, int line) {
    char err;
    fprintf(stderr, "  %s:%d: string_to_fp(\"%s\")\n", __FILE__, line, string);
    strcpy(buffer, string);
    bp = 0;
    err = string_to_fp();
    ASSERT_NE(err, 0);
    ASSERT_EQ(bp, 0);
}

static void test_string_to_fp(void) {
    PRINT_TEST_NAME();

    // 0
    call_string_to_fp("0", POSITIVE, 1, 0x00000000, __LINE__);
    // 1
    call_string_to_fp("1", POSITIVE, 127, 0x80000000, __LINE__);
    // -1
    call_string_to_fp("-1", NEGATIVE, 127, 0x80000000, __LINE__);
    // 10
    call_string_to_fp("10", POSITIVE, 130, 0xA0000000, __LINE__);
    // 25
    call_string_to_fp("25", POSITIVE, 131, 0xC8000000, __LINE__);
    // 100
    call_string_to_fp("100", POSITIVE, 133, 0xC8000000, __LINE__);
    // -100
    call_string_to_fp("-100", NEGATIVE, 133, 0xC8000000, __LINE__);
    // 3.14159
    call_string_to_fp("3.14159", POSITIVE, 128, 0xC90FCF81, __LINE__);
    // 0.0314159
    call_string_to_fp("0.0314159", POSITIVE, 122, 0x80ADF571, __LINE__);
    // 2,147,483,647
    call_string_to_fp("2147483647", POSITIVE, 157, 0xFFFFFFFE, __LINE__);
    // -2,147,483,648
    call_string_to_fp("-2147483648", NEGATIVE, 158, 0x80000000, __LINE__);

    // Verify that string_to_fp stops on non-digit.
    call_string_to_fp("10X", POSITIVE, 130, 0xA0000000, __LINE__);
    call_string_to_fp("-100-", NEGATIVE, 133, 0xC8000000, __LINE__);
    call_string_to_fp("3.14159+", POSITIVE, 128, 0xC90FCF81, __LINE__);
    
    // Verify that string_to_fp leaves bp alone when faced with non-numbers.
    fail_string_to_fp("X10", __LINE__);
    fail_string_to_fp("*3", __LINE__);
    fail_string_to_fp("-X", __LINE__);

//     err = call_string_to_fp("0.0");
//     ASSERT_EQ(err, 0);
//     ASSERT_FLOAT_EQ(reg_fpa, -1, 0);
//     ASSERT_EQ(bp, 3);
//     err = call_string_to_fp(".0");
//     ASSERT_EQ(err, 0);
//     ASSERT_FLOAT_EQ(reg_fpa, -1, 0);
//     ASSERT_EQ(bp, 2);
//     err = call_string_to_fp("0.");
//     ASSERT_EQ(err, 0);
//     ASSERT_FLOAT_EQ(reg_fpa, 0, 0);
//     ASSERT_EQ(bp, 2);
//     err = call_string_to_fp(".");
//     ASSERT_EQ(err, 0);
//     ASSERT_FLOAT_EQ(reg_fpa, 0, 0);
//     ASSERT_EQ(bp, 1);
//     // 100
//     err = call_string_to_fp("100");
//     ASSERT_EQ(err, 0);
//     ASSERT_FLOAT_EQ(reg_fpa, 0, 100);
//     ASSERT_EQ(bp, 3);
//     // -100
//     err = call_string_to_fp("-100");
//     ASSERT_EQ(err, 0);
//     ASSERT_FLOAT_EQ(reg_fpa, 0, -100);
//     ASSERT_EQ(bp, 4);
//     // 2E2
//     err = call_string_to_fp("2E2");
//     ASSERT_EQ(err, 0);
//     ASSERT_FLOAT_EQ(reg_fpa, 2, 2);
//     ASSERT_EQ(bp, 3);
//     // 3.14159
//     err = call_string_to_fp("3.14159");
//     ASSERT_EQ(err, 0);
//     ASSERT_FLOAT_EQ(reg_fpa, -5, 314159);
//     ASSERT_EQ(bp, 7);
//     // 6.0221409E23
//     err = call_string_to_fp("6.0221409E23");
//     ASSERT_EQ(err, 0);
//     ASSERT_FLOAT_EQ(reg_fpa, 16, 60221409);
//     ASSERT_EQ(bp, 12);
//     // Significand limits
//     err = call_string_to_fp("2147483647");
//     ASSERT_EQ(err, 0);
//     ASSERT_FLOAT_EQ(reg_fpa, 0, LONG_MAX);
//     ASSERT_EQ(bp, 10);
//     err = call_string_to_fp("-2147483648");
//     ASSERT_EQ(err, 0);
//     ASSERT_FLOAT_EQ(reg_fpa, 0, LONG_MIN);
//     ASSERT_EQ(bp, 11);
//     // Exponent limits
//     err = call_string_to_fp("1E127");
//     ASSERT_EQ(err, 0);
//     ASSERT_FLOAT_EQ(reg_fpa, 127, 1);
//     ASSERT_EQ(bp, 5);
//     err = call_string_to_fp("1E-127");
//     ASSERT_EQ(err, 0);
//     ASSERT_FLOAT_EQ(reg_fpa, -127, 1);
//     ASSERT_EQ(bp, 6);
//     // Significand out of range 
//     err = call_string_to_fp("2147483648");
//     ASSERT_NE(err, 0);
//     err = call_string_to_fp("-2147483649");
//     ASSERT_NE(err, 0);
//     err = call_string_to_fp("5000000000");
//     ASSERT_NE(err, 0);
//     err = call_string_to_fp("-5000000000");
//     ASSERT_NE(err, 0);
//     // Exponent out of range
//     err = call_string_to_fp("1E128");
//     ASSERT_NE(err, 0);
//     err = call_string_to_fp("1E1000");
//     ASSERT_NE(err, 0);
//     err = call_string_to_fp("1E-128");
//     ASSERT_NE(err, 0);
//     err = call_string_to_fp("1E-1000");
//     ASSERT_NE(err, 0);
//     // Adjusted e out of range
//     err = call_string_to_fp("3.14159E-125");
//     ASSERT_NE(err, 0);
//     // Characters after the number
//     err = call_string_to_fp("10 ");
//     ASSERT_EQ(err, 0);
//     ASSERT_FLOAT_EQ(reg_fpa, 0, 10);
//     ASSERT_EQ(bp, 2);
//     err = call_string_to_fp("10X");
//     ASSERT_EQ(err, 0);
//     ASSERT_FLOAT_EQ(reg_fpa, 0, 10);
//     ASSERT_EQ(bp, 2);
//     err = call_string_to_fp("10. ");
//     ASSERT_EQ(err, 0);
//     ASSERT_FLOAT_EQ(reg_fpa, 0, 10);
//     ASSERT_EQ(bp, 3);
//     err = call_string_to_fp("10.X");
//     ASSERT_EQ(err, 0);
//     ASSERT_FLOAT_EQ(reg_fpa, 0, 10);
//     ASSERT_EQ(bp, 3);
//     err = call_string_to_fp("10E");
//     ASSERT_EQ(err, 0);
//     ASSERT_FLOAT_EQ(reg_fpa, 0, 10);
//     ASSERT_EQ(bp, 3);
//     err = call_string_to_fp("10E ");
//     ASSERT_EQ(err, 0);
//     ASSERT_FLOAT_EQ(reg_fpa, 0, 10);
//     ASSERT_EQ(bp, 3);
//     err = call_string_to_fp("10EX");
//     ASSERT_EQ(err, 0);
//     ASSERT_FLOAT_EQ(reg_fpa, 0, 10);
//     ASSERT_EQ(bp, 3);
//     err = call_string_to_fp("10E1 ");
//     ASSERT_EQ(err, 0);
//     ASSERT_FLOAT_EQ(reg_fpa, 1, 10);
//     ASSERT_EQ(bp, 4);
//     err = call_string_to_fp("10E-1 ");
//     ASSERT_EQ(err, 0);
//     ASSERT_FLOAT_EQ(reg_fpa, -1, 10);
//     ASSERT_EQ(bp, 5);
//     // Various empty values
//     err = call_string_to_fp("");
//     ASSERT_NE(err, 0);
//     err = call_string_to_fp(" ");
//     ASSERT_NE(err, 0);
//     err = call_string_to_fp("E");
//     ASSERT_NE(err, 0);
//     err = call_string_to_fp("E1");
//     ASSERT_NE(err, 0);
//     err = call_string_to_fp("X");
//     ASSERT_NE(err, 0);
//     err = call_string_to_fp("- ");
//     ASSERT_NE(err, 0);
//     err = call_string_to_fp("-E1");
//     ASSERT_NE(err, 0);
//     err = call_string_to_fp("-X");
//     ASSERT_NE(err, 0);
}

int main(void) {
    initialize_target();
    test_load_fpx();
    test_store_fpx();
    test_swap_fp0_fp1();
    test_adjust_exponent();
    test_normalize();
    test_int_to_fp();
    test_int32_to_fp();
    test_truncate_fp_to_int();
    test_truncate_fp_to_int32();
    test_fadd();
    test_fsub();
    test_fmul();
    test_fdiv();
    test_fcmp();
    test_char_to_digit();
    test_fp_to_string();
    test_string_to_fp();
    return 0;
}
