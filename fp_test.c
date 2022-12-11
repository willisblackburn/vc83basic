#include "test.h"

#define POSITIVE ((char)0x00)
#define NEGATIVE ((char)0x80)

#define SET_FLOAT(value, e_value, t_value) do { \
    value.e = (e_value); \
    value.t = (t_value); \
} while (0)

#define SET_FPX(fpx, s_value, e_value, t_value) do { \
    fpx.s = (s_value); \
    fpx.e = (e_value); \
    fpx.t = (t_value); \
} while (0)

#define ASSERT_FLOAT_EQ(value, e_value, t_value) do { \
    ASSERT_EQ(value.e, e_value); \
    ASSERT_EQ(value.t, t_value); \
} while (0)

#define ASSERT_FPX_EQ(fpx, s_value, e_value, t_value) do { \
    ASSERT_EQ(fpx.s, s_value); \
    ASSERT_EQ(fpx.e, e_value); \
    ASSERT_EQ(fpx.t, t_value); \
} while (0)

static void test_load_fpa(void) {
    Float value;
    PRINT_TEST_NAME();
    SET_FLOAT(value, 1, 1418858818L);
    clear_fpa();
    load_fpa(&value);
    ASSERT_FLOAT_EQ(reg_fpa, 1, 1418858818L);
}

static void test_store_fpa(void) {
    Float value;
    PRINT_TEST_NAME();
    SET_FLOAT(reg_fpa, 1, 1418858818L);
    store_fpa(&value);
    ASSERT_FLOAT_EQ(value, 1, 1418858818L);
}

static void test_clear_fpa(void) {
    PRINT_TEST_NAME();
    SET_FLOAT(reg_fpa, 1, 1418858818L);
    clear_fpa();
    ASSERT_FLOAT_EQ(reg_fpa, 0, 0);
}

static void test_fp_is_zero(void) {
    int result;
    PRINT_TEST_NAME();
    SET_FLOAT(reg_fpa, 1, 1418858818L);
    result = fpa_is_zero();
    ASSERT_EQ(result, 0);
    SET_FLOAT(reg_fpa, 0, 0L);
    result = fpa_is_zero();
    ASSERT_EQ(result, 1);
    SET_FLOAT(reg_fpa, 1, 0L);
    result = fpa_is_zero();
    ASSERT_EQ(result, 1);
}

static void test_fneg(void) {
    PRINT_TEST_NAME();
    SET_FLOAT(reg_fpa, 1, 1418858818L);
    fneg();
    ASSERT_FLOAT_EQ(reg_fpa, 1, -1418858818L);
    fneg();
    ASSERT_FLOAT_EQ(reg_fpa, 1, 1418858818L);
}

static void test_char_to_digit(void) {
    int err;

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

void test_swap_fpa(void) {
    Float value;
    PRINT_TEST_NAME();
    clear_fpa();
    SET_FLOAT(value, 1, 1418858818L);
    swap_fpa(&value);
    ASSERT_FLOAT_EQ(reg_fpa, 1, 1418858818L);
    ASSERT_FLOAT_EQ(value, 0, 0);
}

static void test_int_to_fp(void) {
    PRINT_TEST_NAME();
    // 0
    int_to_fp(0);
    ASSERT_FLOAT_EQ(reg_fpa, 0, 0);
    // 100
    int_to_fp(100);
    ASSERT_FLOAT_EQ(reg_fpa, 0, 100);
    // 1000
    int_to_fp(1000);
    ASSERT_FLOAT_EQ(reg_fpa, 0, 1000);
    // -1
    int_to_fp(-1);
    ASSERT_FLOAT_EQ(reg_fpa, 0, -1);
    // -1000
    int_to_fp(-1000);
    ASSERT_FLOAT_EQ(reg_fpa, 0, -1000);
    // 32767
    int_to_fp(32767);
    ASSERT_FLOAT_EQ(reg_fpa, 0, 32767);
    // -32768
    int_to_fp((int)-32768L);
    ASSERT_FLOAT_EQ(reg_fpa, 0, -32768L);
}

static void test_truncate_fp_to_int(void) {
    char err;
    int* int_value_ptr = (int*)((char*)&reg_fpa + offsetof(Float, t));

    PRINT_TEST_NAME();

    // 0
    SET_FLOAT(reg_fpa, 0, 0);
    err = truncate_fp_to_int();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(*int_value_ptr, 0);
    // 10 as 10E+0
    SET_FLOAT(reg_fpa, 0, 10);
    err = truncate_fp_to_int();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(*int_value_ptr, 10);
    // 10 as 1E+1
    SET_FLOAT(reg_fpa, 1, 1);
    err = truncate_fp_to_int();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(*int_value_ptr, 10);
    // 10 as 100E-1
    SET_FLOAT(reg_fpa, -1, 100);
    err = truncate_fp_to_int();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(*int_value_ptr, 10);
    // -10
    SET_FLOAT(reg_fpa, 0, -10);
    err = truncate_fp_to_int();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(*int_value_ptr, -10);
    // 3.14159 -> 3
    SET_FLOAT(reg_fpa, -5, 314159);
    err = truncate_fp_to_int();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(*int_value_ptr, 3);
    // 32767
    SET_FLOAT(reg_fpa, 0, 32767);
    err = truncate_fp_to_int();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(*int_value_ptr, 32767);
    // -32768
    SET_FLOAT(reg_fpa, 0, (int)-32768L);
    err = truncate_fp_to_int();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(*int_value_ptr, (int)-32768L);
    // 100000 -> overflow
    SET_FLOAT(reg_fpa, 5, 1);
    err = truncate_fp_to_int();
}

static void call_fp_to_string(void) {
    bp = 0;
    fp_to_string();
    buffer[bp] = '\0';
}

static void test_fp_to_string(void) {

    PRINT_TEST_NAME();

    // 0
    SET_FLOAT(reg_fpa, 0, 0);
    call_fp_to_string();
    ASSERT_STRING_EQ(buffer, "0");
    // 100
    SET_FLOAT(reg_fpa, 0, 100);
    call_fp_to_string();
    ASSERT_STRING_EQ(buffer, "100");
    // -100
    SET_FLOAT(reg_fpa, 0, -100);
    call_fp_to_string();
    ASSERT_STRING_EQ(buffer, "-100");
    // 2E2 (should be 200 since value is in printable range)
    SET_FLOAT(reg_fpa, 2, 2);
    call_fp_to_string();
    ASSERT_STRING_EQ(buffer, "200");
    // 3.14159
    SET_FLOAT(reg_fpa, -5, 314159);
    call_fp_to_string();
    ASSERT_STRING_EQ(buffer, "3.14159");
    // 0.0314159
    SET_FLOAT(reg_fpa, -7, 314159);
    call_fp_to_string();
    ASSERT_STRING_EQ(buffer, "0.0314159");
    // 6.0221409E23
    SET_FLOAT(reg_fpa, 16, 60221409);
    call_fp_to_string();
    ASSERT_STRING_EQ(buffer, "6.0221409E23");
    // 0.00729734813
    SET_FLOAT(reg_fpa, -11, 729734813);
    call_fp_to_string();
    ASSERT_STRING_EQ(buffer, "7.29734813E-3");

    // Exponent edge cases
    // +/- 1E9 should print without E
    // +/- 1E10 should print in scientific
    SET_FLOAT(reg_fpa, 9, 1);
    call_fp_to_string();
    ASSERT_STRING_EQ(buffer, "1000000000");
    SET_FLOAT(reg_fpa, 9, -1);
    call_fp_to_string();
    ASSERT_STRING_EQ(buffer, "-1000000000");
    SET_FLOAT(reg_fpa, 10, 1);
    call_fp_to_string();
    ASSERT_STRING_EQ(buffer, "1E10");
    SET_FLOAT(reg_fpa, 10, -1);
    call_fp_to_string();
    ASSERT_STRING_EQ(buffer, "-1E10");
    // Test for logic that removes trailing zeros
    SET_FLOAT(reg_fpa, -2, 1000);
    call_fp_to_string();
    ASSERT_STRING_EQ(buffer, "10");
    SET_FLOAT(reg_fpa, -6, 1000);
    call_fp_to_string();
    ASSERT_STRING_EQ(buffer, "0.001");
    SET_FLOAT(reg_fpa, 15, 100);
    call_fp_to_string();
    ASSERT_STRING_EQ(buffer, "1E17");
}

static int call_string_to_fp(const char* s) {
    strcpy(buffer, s);
    bp = 0;
    return string_to_fp();
}

static void test_string_to_fp(void) {
    int err;

    PRINT_TEST_NAME();

    // 0
    err = call_string_to_fp("0");
    ASSERT_EQ(err, 0);
    ASSERT_FLOAT_EQ(reg_fpa, 0, 0);
    ASSERT_EQ(bp, 1);
    err = call_string_to_fp("0.0");
    ASSERT_EQ(err, 0);
    ASSERT_FLOAT_EQ(reg_fpa, -1, 0);
    ASSERT_EQ(bp, 3);
    err = call_string_to_fp(".0");
    ASSERT_EQ(err, 0);
    ASSERT_FLOAT_EQ(reg_fpa, -1, 0);
    ASSERT_EQ(bp, 2);
    err = call_string_to_fp("0.");
    ASSERT_EQ(err, 0);
    ASSERT_FLOAT_EQ(reg_fpa, 0, 0);
    ASSERT_EQ(bp, 2);
    err = call_string_to_fp(".");
    ASSERT_EQ(err, 0);
    ASSERT_FLOAT_EQ(reg_fpa, 0, 0);
    ASSERT_EQ(bp, 1);
    // 100
    err = call_string_to_fp("100");
    ASSERT_EQ(err, 0);
    ASSERT_FLOAT_EQ(reg_fpa, 0, 100);
    ASSERT_EQ(bp, 3);
    // -100
    err = call_string_to_fp("-100");
    ASSERT_EQ(err, 0);
    ASSERT_FLOAT_EQ(reg_fpa, 0, -100);
    ASSERT_EQ(bp, 4);
    // 2E2
    err = call_string_to_fp("2E2");
    ASSERT_EQ(err, 0);
    ASSERT_FLOAT_EQ(reg_fpa, 2, 2);
    ASSERT_EQ(bp, 3);
    // 3.14159
    err = call_string_to_fp("3.14159");
    ASSERT_EQ(err, 0);
    ASSERT_FLOAT_EQ(reg_fpa, -5, 314159);
    ASSERT_EQ(bp, 7);
    // 6.0221409E23
    err = call_string_to_fp("6.0221409E23");
    ASSERT_EQ(err, 0);
    ASSERT_FLOAT_EQ(reg_fpa, 16, 60221409);
    ASSERT_EQ(bp, 12);
    // Significand limits
    err = call_string_to_fp("2147483647");
    ASSERT_EQ(err, 0);
    ASSERT_FLOAT_EQ(reg_fpa, 0, LONG_MAX);
    ASSERT_EQ(bp, 10);
    err = call_string_to_fp("-2147483648");
    ASSERT_EQ(err, 0);
    ASSERT_FLOAT_EQ(reg_fpa, 0, LONG_MIN);
    ASSERT_EQ(bp, 11);
    // Exponent limits
    err = call_string_to_fp("1E127");
    ASSERT_EQ(err, 0);
    ASSERT_FLOAT_EQ(reg_fpa, 127, 1);
    ASSERT_EQ(bp, 5);
    err = call_string_to_fp("1E-127");
    ASSERT_EQ(err, 0);
    ASSERT_FLOAT_EQ(reg_fpa, -127, 1);
    ASSERT_EQ(bp, 6);
    // Significand out of range 
    err = call_string_to_fp("2147483648");
    ASSERT_NE(err, 0);
    err = call_string_to_fp("-2147483649");
    ASSERT_NE(err, 0);
    err = call_string_to_fp("5000000000");
    ASSERT_NE(err, 0);
    err = call_string_to_fp("-5000000000");
    ASSERT_NE(err, 0);
    // Exponent out of range
    err = call_string_to_fp("1E128");
    ASSERT_NE(err, 0);
    err = call_string_to_fp("1E1000");
    ASSERT_NE(err, 0);
    err = call_string_to_fp("1E-128");
    ASSERT_NE(err, 0);
    err = call_string_to_fp("1E-1000");
    ASSERT_NE(err, 0);
    // Adjusted e out of range
    err = call_string_to_fp("3.14159E-125");
    ASSERT_NE(err, 0);
    // Characters after the number
    err = call_string_to_fp("10 ");
    ASSERT_EQ(err, 0);
    ASSERT_FLOAT_EQ(reg_fpa, 0, 10);
    ASSERT_EQ(bp, 2);
    err = call_string_to_fp("10X");
    ASSERT_EQ(err, 0);
    ASSERT_FLOAT_EQ(reg_fpa, 0, 10);
    ASSERT_EQ(bp, 2);
    err = call_string_to_fp("10. ");
    ASSERT_EQ(err, 0);
    ASSERT_FLOAT_EQ(reg_fpa, 0, 10);
    ASSERT_EQ(bp, 3);
    err = call_string_to_fp("10.X");
    ASSERT_EQ(err, 0);
    ASSERT_FLOAT_EQ(reg_fpa, 0, 10);
    ASSERT_EQ(bp, 3);
    err = call_string_to_fp("10E");
    ASSERT_EQ(err, 0);
    ASSERT_FLOAT_EQ(reg_fpa, 0, 10);
    ASSERT_EQ(bp, 3);
    err = call_string_to_fp("10E ");
    ASSERT_EQ(err, 0);
    ASSERT_FLOAT_EQ(reg_fpa, 0, 10);
    ASSERT_EQ(bp, 3);
    err = call_string_to_fp("10EX");
    ASSERT_EQ(err, 0);
    ASSERT_FLOAT_EQ(reg_fpa, 0, 10);
    ASSERT_EQ(bp, 3);
    err = call_string_to_fp("10E1 ");
    ASSERT_EQ(err, 0);
    ASSERT_FLOAT_EQ(reg_fpa, 1, 10);
    ASSERT_EQ(bp, 4);
    err = call_string_to_fp("10E-1 ");
    ASSERT_EQ(err, 0);
    ASSERT_FLOAT_EQ(reg_fpa, -1, 10);
    ASSERT_EQ(bp, 5);
    // Various empty values
    err = call_string_to_fp("");
    ASSERT_NE(err, 0);
    err = call_string_to_fp(" ");
    ASSERT_NE(err, 0);
    err = call_string_to_fp("E");
    ASSERT_NE(err, 0);
    err = call_string_to_fp("E1");
    ASSERT_NE(err, 0);
    err = call_string_to_fp("X");
    ASSERT_NE(err, 0);
    err = call_string_to_fp("- ");
    ASSERT_NE(err, 0);
    err = call_string_to_fp("-E1");
    ASSERT_NE(err, 0);
    err = call_string_to_fp("-X");
    ASSERT_NE(err, 0);
}

static void test_fadd(void) {
    Float value;

    PRINT_TEST_NAME();

    // 0 + 0
    SET_FLOAT(reg_fpa, 0, 0);
    SET_FLOAT(value, 0, 0);
    fadd(&value);
    ASSERT_FLOAT_EQ(reg_fpa, 0, 0);
    // 1 + 1
    SET_FLOAT(reg_fpa, 0, 1);
    SET_FLOAT(value, 0, 1);
    fadd(&value);
    ASSERT_FLOAT_EQ(reg_fpa, 0, 2);
    // 1 + 1E1
    SET_FLOAT(reg_fpa, 0, 1);
    SET_FLOAT(value, 1, 1);
    fadd(&value);
    ASSERT_FLOAT_EQ(reg_fpa, 0, 11);
    // 1E1 + 1
    SET_FLOAT(reg_fpa, 1, 1);
    SET_FLOAT(value, 0, 1);
    fadd(&value);
    ASSERT_FLOAT_EQ(reg_fpa, 0, 11);
    // 1 + 3.14159
    SET_FLOAT(reg_fpa, 0, 1);
    SET_FLOAT(value, -5, 314159);
    fadd(&value);
    ASSERT_FLOAT_EQ(reg_fpa, -5, 414159);
    // 1 + -1
    SET_FLOAT(reg_fpa, 0, 1);
    SET_FLOAT(value, 0, -1);
    fadd(&value);
    ASSERT_FLOAT_EQ(reg_fpa, 0, 0);
    // 1E1 + -1
    SET_FLOAT(reg_fpa, 1, 1);
    SET_FLOAT(value, 0, -1);
    fadd(&value);
    ASSERT_FLOAT_EQ(reg_fpa, 0, 9);
    // 1 + -1E1
    SET_FLOAT(reg_fpa, 0, 1);
    SET_FLOAT(value, 1, -1);
    fadd(&value);
    ASSERT_FLOAT_EQ(reg_fpa, 0, -9);
    // // LONG_MAX + 1
    // SET_FLOAT(reg_fpa, 0, LONG_MAX);
    // SET_FLOAT(value, 0, 1);
    // fadd(&value);
    // ASSERT_FLOAT_EQ(reg_fpa, 1, -9);
}

static void test_fsub(void) {
    Float value;

    PRINT_TEST_NAME();

    // Don't need many fsub tests since it just negates its argument and calls fadd.

    // 3.14159 - 1.14159 = 2
    SET_FLOAT(reg_fpa, -5, 314159);
    SET_FLOAT(value, -5, 114159);
    fsub(&value);
    ASSERT_FLOAT_EQ(reg_fpa, -5, 200000);
    // -100 - 2.5 = -102.5
    SET_FLOAT(reg_fpa, 2, -1);
    SET_FLOAT(value, -1, 25);
    fsub(&value);
    ASSERT_FLOAT_EQ(reg_fpa, -1, -1025);
}

static void test_fmul(void) {
    Float value;

    PRINT_TEST_NAME();

    // 0 * 0 = 0
    SET_FLOAT(reg_fpa, 0, 0);
    SET_FLOAT(value, 0, 0);
    fmul(&value);
    ASSERT_FLOAT_EQ(reg_fpa, 0, 0);
    // 1 * 1 = 1
    SET_FLOAT(reg_fpa, 0, 1);
    SET_FLOAT(value, 0, 1);
    fmul(&value);
    ASSERT_FLOAT_EQ(reg_fpa, 0, 1);
    // 1E1 * 1 = 1E1
    SET_FLOAT(reg_fpa, 1, 1);
    SET_FLOAT(value, 0, 1);
    fmul(&value);
    ASSERT_FLOAT_EQ(reg_fpa, 1, 1);
    // 1,000,000,000 * 1,000,000,000
    SET_FLOAT(reg_fpa, 0, 1000000000);
    SET_FLOAT(value, 0, 1000000000);
    fmul(&value);
    ASSERT_FLOAT_EQ(reg_fpa, 9, 1000000000);
    // 3.14159 * 1E5 = 314159
    SET_FLOAT(reg_fpa, -5, 314159);
    SET_FLOAT(value, 5, 1);
    fmul(&value);
    ASSERT_FLOAT_EQ(reg_fpa, 0, 314159);
    // 1 * -1 = -1
    SET_FLOAT(reg_fpa, 0, 1);
    SET_FLOAT(value, 0, -1);
    fmul(&value);
    ASSERT_FLOAT_EQ(reg_fpa, 0, -1);
    // -1 * 1 = -1
    SET_FLOAT(reg_fpa, 0, -1);
    SET_FLOAT(value, 0, 1);
    fmul(&value);
    ASSERT_FLOAT_EQ(reg_fpa, 0, -1);
    // -1 * -1 = 1
    SET_FLOAT(reg_fpa, 0, -1);
    SET_FLOAT(value, 0, -1);
    fmul(&value);
    ASSERT_FLOAT_EQ(reg_fpa, 0, 1);
    // 3.14159 * 3.14159
    // TODO: should round up not truncate
    SET_FLOAT(reg_fpa, -5, 314159);
    SET_FLOAT(value, -5, 314159);
    fmul(&value);
    ASSERT_FLOAT_EQ(reg_fpa, -8, 986958772);
}

static void test_fdiv(void) {
    Float value;

    PRINT_TEST_NAME();
    
    // 1 / 1 = 1
    SET_FLOAT(reg_fpa, 0, 1);
    SET_FLOAT(value, 0, 1);
    fdiv(&value);
    ASSERT_FLOAT_EQ(reg_fpa, 0, 1);
    
    SET_FLOAT(reg_fpa, 0, 10);
    SET_FLOAT(value, 0, 1);
    fdiv(&value);
    ASSERT_FLOAT_EQ(reg_fpa, 0, 10);
    
    // 1000000000 / 1 = 1000000000
    SET_FLOAT(reg_fpa, 0, 1000000000);
    SET_FLOAT(value, 0, 1);
    fdiv(&value);
    ASSERT_FLOAT_EQ(reg_fpa, 0, 1000000000);
    
    // 8 / 2 = 4
    SET_FLOAT(reg_fpa, 0, 8);
    SET_FLOAT(value, 0, 2);
    fdiv(&value);
    ASSERT_FLOAT_EQ(reg_fpa, 0, 4);
    
    // 3.14159 / 1 = 3.14159
    SET_FLOAT(reg_fpa, -5, 314159);
    SET_FLOAT(value, 0, 1);
    fdiv(&value);
    ASSERT_FLOAT_EQ(reg_fpa, -5, 314159);
    
    // 3.14159 / 1E1 = 0.314159
    SET_FLOAT(reg_fpa, -5, 314159);
    SET_FLOAT(value, 1, 1);
    fdiv(&value);
    ASSERT_FLOAT_EQ(reg_fpa, -6, 314159);
    
    // 3 / 10 = 0.3
    SET_FLOAT(reg_fpa, 0, 3);
    SET_FLOAT(value, 0, 10);
    fdiv(&value);
    ASSERT_FLOAT_EQ(reg_fpa, -1, 3);
    
    // 3.14159 / 10 = 0.314159
    SET_FLOAT(reg_fpa, -5, 314159);
    SET_FLOAT(value, 0, 10);
    fdiv(&value);
    ASSERT_FLOAT_EQ(reg_fpa, -6, 314159);
}

static void test_fcmp(void) {
    Float value;
    int result;

    PRINT_TEST_NAME();
    
    // 0 <=> 0 = 0
    SET_FLOAT(reg_fpa, 0, 0);
    SET_FLOAT(value, 0, 0);
    result = fcmp(&value);
    ASSERT_EQ(result, 0);

    // 1 <=> 1 = 0
    SET_FLOAT(reg_fpa, 0, 1);
    SET_FLOAT(value, 0, 1);
    result = fcmp(&value);
    ASSERT_EQ(result, 0);

    // 1 <=> 0 = 1
    SET_FLOAT(reg_fpa, 0, 1);
    SET_FLOAT(value, 0, 0);
    result = fcmp(&value);
    ASSERT_EQ(result, 1);

    // 0 <=> 1 = -1
    SET_FLOAT(reg_fpa, 0, 0);
    SET_FLOAT(value, 0, 1);
    result = fcmp(&value);
    ASSERT_EQ(result, -1);

    // 1E1 <=> 1 = 1
    SET_FLOAT(reg_fpa, 1, 1);
    SET_FLOAT(value, 0, 1);
    result = fcmp(&value);
    ASSERT_EQ(result, 1);

    // 1 <=> 1E1 = -1
    SET_FLOAT(reg_fpa, 0, 1);
    SET_FLOAT(value, 1, 1);
    result = fcmp(&value);
    ASSERT_EQ(result, -1);

    // 10 <=> 1E1 = 0
    SET_FLOAT(reg_fpa, 0, 10);
    SET_FLOAT(value, 1, 1);
    result = fcmp(&value);
    ASSERT_EQ(result, 0);
    
    // 0 <=> 1000 = 0
    SET_FLOAT(reg_fpa, 0, 0);
    SET_FLOAT(value, 0, 1000);
    result = fcmp(&value);
    ASSERT_EQ(result, -1);
}    

// --------------------------------------------------------------------------------------------------------------------

typedef struct LoadStoreTestCase {
    Float f;
    UnpackedFloat u;
} LoadStoreTestCase;

static LoadStoreTestCase load_store_test_cases[] = {
    { { 0x00000000, 0 }, { 0x00000000, 1, POSITIVE } },
    { { 0x00000000, 128 }, { 0x80000000, 128, POSITIVE } },
    { { 0x7FFFFFFE, 158 }, { 0xFFFFFFFE, 158, POSITIVE } },
    { { 0x80000000, 159 }, { 0x80000000, 159, NEGATIVE } },
    { { 0x08442211, 128 }, { 0x88442211, 128, POSITIVE } },
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
        fprintf(stderr, "  fp_test.c:%d: load_fpx(t=$%08X, e=$%02X)\n", __LINE__, 
                test_case->f.t, test_case->f.e);
        SET_FLOAT(value, test_case->f.e, test_case->f.t);
        load_fpx(&FP0, &value);
        ASSERT_EQ(FP0s, test_case->u.s);
        ASSERT_EQ(FP0e, test_case->u.e);
        ASSERT_EQ(FP0t, test_case->u.t);
        load_fpx(&FP1, &value);
        ASSERT_EQ(FP1s, test_case->u.s);
        ASSERT_EQ(FP1e, test_case->u.e);
        ASSERT_EQ(FP1t, test_case->u.t);
    }
}

static void test_store_fpx(void) {
    Float value;
    LoadStoreTestCase* test_case;
    int i;

    PRINT_TEST_NAME();

    for (i = 0; i < sizeof load_store_test_cases / sizeof *load_store_test_cases; i++) {
        test_case = load_store_test_cases + i;
        fprintf(stderr, "store_fpx(fp_test.c:%d: t=$%08X, e=$%02X, s=$%02X)\n", __LINE__,
                test_case->u.t, test_case->u.e, test_case->u.s);
        FP0s = test_case->u.s;
        FP0e = test_case->u.e;
        FP0t = test_case->u.t;
        store_fpx(&FP0, &value);
        ASSERT_FLOAT_EQ(value, test_case->f.e, test_case->f.t);
        FP1s = test_case->u.s;
        FP1e = test_case->u.e;
        FP1t = test_case->u.t;
        store_fpx(&FP1, &value);
        ASSERT_FLOAT_EQ(value, test_case->f.e, test_case->f.t);
    }
}

// static void test_swap_fp0_fp1(void) {
//     PRINT_TEST_NAME();
//     SET_FLOAT(FP0, 2, 12345678L);
//     SET_FLOAT(FP1, 1, 1418858818L);
//     swap_fp0_fp1();
//     ASSERT_FLOAT_EQ(FP0, 1, 1418858818L);
//     ASSERT_FLOAT_EQ(FP1, 2, 12345678L);
// }

static void call_normalize(char s, char e, long x, long t, char grs, char expect_e, long expect_t, int line) {
    FP0s = s;
    FP0e = e;
    FP0t = t;
    FP0x = x;
    FPr = grs;
    fprintf(stderr, "  fp_test.c:%d: normalize(xt=$%08LX%08LX e=%02X s=%02X grs=%02X)\n", line, x, t, e, s, grs);
    normalize();
    ASSERT_FLOAT_EQ(FP0, expect_e, expect_t);
}

static void test_normalize(void) {
    PRINT_TEST_NAME();

    // 0
    call_normalize(POSITIVE, 1, 0, 0, 0, 1, 0, __LINE__);
    // 0 significand with any exponent normalizes to 0
    call_normalize(POSITIVE, 127, 0, 0, 0, 1, 0, __LINE__);
    // 1
    call_normalize(POSITIVE, 128, 0x00, 0x00000001, 0x00, 97, 0x80000000, __LINE__);
    // -1
    call_normalize(NEGATIVE, 128, 0x00, 0x00000001, 0x00, 97, 0x80000000, __LINE__);
    // 32,767
    call_normalize(POSITIVE, 158, 0x00, 0x00007FFF, 0x00, 141, 0xFFFE0000, __LINE__);
    // 2,147,483,647
    call_normalize(POSITIVE, 158, 0x00, 0x7FFFFFFF, 0x00, 157, 0xFFFFFFFE, __LINE__);
    // -2,147,483,648
    call_normalize(NEGATIVE, 158, 0x00, 0x80000000, 0x00, 158, 0x80000000, __LINE__);
    // 2,286,166,545
    call_normalize(POSITIVE, 158, 0x00, 0x88442211, 0x00, 158, 0x88442211, __LINE__);
    // 4,294,967,296
    call_normalize(POSITIVE, 158, 0x01, 0x00000000, 0x00, 159, 0x80000000, __LINE__);
    // Subnormal
    call_normalize(POSITIVE, 9, 0x00, 0x00001234, 0x00, 1, 0x00123400, __LINE__);
    call_normalize(POSITIVE, 8, 0x00, 0x00001234, 0x00, 1, 0x00091A00, __LINE__);
}

// static void call_int_to_fp2(long value, char expect_e, long expect_t) {
//     SET_FLOAT(FP0, 0, value);
//     fprintf(stderr, "int_to_fp2(%ld)\n", value);
//     int_to_fp2();
//     ASSERT_FLOAT_EQ(FP0, expect_e, expect_t);
// }

// static void test_int_to_fp2(void) {
//     PRINT_TEST_NAME();

//     call_int_to_fp2(0, 0, 0x00000000);
//     call_int_to_fp2(1, 0, 0x40000000);
//     call_int_to_fp2(-1, -1, 0x80000000);
//     call_int_to_fp2(32767, 14, 0x7FFF0000);
//     call_int_to_fp2(-32768, 14, 0x80000000);
//     call_int_to_fp2(4112, 12, 0x40400000);
// }

// static void call_truncate_fp_to_int2(char e, long s, long expect_value) {
//     int err;
//     SET_FLOAT(FP0, e, s);
//     fprintf(stderr, "truncate_fp_to_int2(%d, $%08LX)\n", e, s);
//     err = truncate_fp_to_int2();
//     ASSERT_EQ(err, 0);
//     ASSERT_EQ(FP0s, expect_value);
// }

// static void test_truncate_fp_to_int2(void) {
//     int result;

//     PRINT_TEST_NAME();
    
//     // Same cases as in test_int_to_fp2, only in reverse.

//     call_truncate_fp_to_int2(0, 0x00000000, 0);
//     call_truncate_fp_to_int2(0, 0x40000000, 1);
//     // call_truncate_fp_to_int2(-1, 0x80000000, -1);
//     call_truncate_fp_to_int2(14, 0x7FFF0000, 32767);
//     call_truncate_fp_to_int2(14, 0x80000000, -32768);
//     call_truncate_fp_to_int2(12, 0x40400000, 4112);
// }

static void call_fadd2(char s_0, char e_0, long t_0, char s_1, char e_1, long t_1,
                       char expect_s, char expect_e, long expect_t, int line) {
    SET_FPX(FP0, s_0, e_0, t_0);
    SET_FPX(FP1, s_1, e_1, t_1);
    fprintf(stderr, "  fp_test.c:%d: fadd(t=%08LX e=%02X s=%02X, t=%08LX e=%02X s=%02X)\n", line,
            t_0, e_0, s_0, t_1, e_1, s_1);
    fadd2();
    ASSERT_FPX_EQ(FP0, expect_s, expect_e, expect_t);
}

static void test_fadd2(void) {
    PRINT_TEST_NAME();

    // 0 + 0
    call_fadd2(POSITIVE, 1, 0, POSITIVE, 1, 0, POSITIVE, 1, 0, __LINE__);
    // 1 + 1
    call_fadd2(POSITIVE, 128, 0x80000000, POSITIVE, 128, 0x80000000, POSITIVE, 129, 0x80000000, __LINE__);
    // 0.5 + 0.5
    call_fadd2(POSITIVE, 127, 0x80000000, POSITIVE, 127, 0x80000000, POSITIVE, 128, 0x80000000, __LINE__);
    // -1 + (-1)
    call_fadd2(NEGATIVE, 128, 0x80000000, NEGATIVE, 128, 0x80000000, NEGATIVE, 129, 0x80000000, __LINE__);
    // 1 + (-1)
    call_fadd2(POSITIVE, 128, 0x80000000, NEGATIVE, 128, 0x80000000, POSITIVE, 1, 0, __LINE__);
    // -2 + 1
    call_fadd2(NEGATIVE, 129, 0x80000000, POSITIVE, 128, 0x80000000, NEGATIVE, 128, 0x80000000, __LINE__);
    // 1 + (-2)
    call_fadd2(POSITIVE, 128, 0x80000000, NEGATIVE, 129, 0x80000000, NEGATIVE, 128, 0x80000000, __LINE__);
    // -1 + 2
    call_fadd2(NEGATIVE, 128, 0x80000000, POSITIVE, 129, 0x80000000, POSITIVE, 128, 0x80000000, __LINE__);
    // 2 + (-1)
    call_fadd2(POSITIVE, 129, 0x80000000, NEGATIVE, 128, 0x80000000, POSITIVE, 128, 0x80000000, __LINE__);
    // 1 + 0.0001220703125
    call_fadd2(POSITIVE, 128, 0x80000000, POSITIVE, 115, 0x80000000, POSITIVE, 128, 0x80040000, __LINE__);
    // 1 + 3.14159
    call_fadd2(POSITIVE, 128, 0x80000000, POSITIVE, 129, 0xC90FCF80, POSITIVE, 130, 0x8487E7C0, __LINE__);
    // 1 + 0.00000000046566128730
    call_fadd2(POSITIVE, 128, 0x80000000, POSITIVE, 97, 0x80000000, POSITIVE, 128, 0x80000001, __LINE__);
    // 1 + 0.00000000011641532182 (should round down)
    call_fadd2(POSITIVE, 128, 0x80000000, POSITIVE, 95, 0x80000000, POSITIVE, 128, 0x80000000, __LINE__);
    // 1 + 0.00000000023283064365 (should round up)
    call_fadd2(POSITIVE, 128, 0x80000000, POSITIVE, 96, 0x80000000, POSITIVE, 128, 0x80000001, __LINE__);
    // 1 + 0.00000000034924596547 (should round up)
    call_fadd2(POSITIVE, 128, 0x80000000, POSITIVE, 96, 0xC0000000, POSITIVE, 128, 0x80000001, __LINE__);
    
    // // 1 + 1E1
    // SET_FLOAT(reg_fpa, 0, 1);
    // SET_FLOAT(value, 1, 1);
    // fadd(&value);
    // ASSERT_FLOAT_EQ(reg_fpa, 0, 11);
    // // 1E1 + 1
    // SET_FLOAT(reg_fpa, 1, 1);
    // SET_FLOAT(value, 0, 1);
    // fadd(&value);
    // ASSERT_FLOAT_EQ(reg_fpa, 0, 11);
    // // 1 + 3.14159
    // SET_FLOAT(reg_fpa, 0, 1);
    // SET_FLOAT(value, -5, 314159);
    // fadd(&value);
    // ASSERT_FLOAT_EQ(reg_fpa, -5, 414159);
    // // 1 + -1
    // SET_FLOAT(reg_fpa, 0, 1);
    // SET_FLOAT(value, 0, -1);
    // fadd(&value);
    // ASSERT_FLOAT_EQ(reg_fpa, 0, 0);
    // // 1E1 + -1
    // SET_FLOAT(reg_fpa, 1, 1);
    // SET_FLOAT(value, 0, -1);
    // fadd(&value);
    // ASSERT_FLOAT_EQ(reg_fpa, 0, 9);
    // // 1 + -1E1
    // SET_FLOAT(reg_fpa, 0, 1);
    // SET_FLOAT(value, 1, -1);
    // fadd(&value);
    // ASSERT_FLOAT_EQ(reg_fpa, 0, -9);
    // // LONG_MAX + 1
    // SET_FLOAT(reg_fpa, 0, LONG_MAX);
    // SET_FLOAT(value, 0, 1);
    // fadd(&value);
    // ASSERT_FLOAT_EQ(reg_fpa, 1, -9);
}

int main(void) {
    initialize_target();
    // test_load_fpa();
    // test_store_fpa();
    // test_clear_fpa();
    // test_fp_is_zero();
    // test_fneg();
    // test_char_to_digit();
    // test_swap_fpa();
    // test_int_to_fp();
    // test_truncate_fp_to_int();
    // test_fp_to_string();
    // test_string_to_fp();
    // test_fadd();
    // test_fsub();
    // test_fmul();
    // test_fdiv();
    // test_fcmp();
    test_load_fpx();
    test_store_fpx();
    // test_swap_fp0_fp1();
    test_normalize();
    // test_int_to_fp2();
    // test_truncate_fp_to_int2();
    test_fadd2();
    return 0;
}
