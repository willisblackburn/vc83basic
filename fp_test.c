#include "test.h"

#define SET_FP(value, e_value, s_value) do { \
    value.e = (e_value); \
    value.s = (s_value); \
} while (0)

#define ASSERT_FP_EQ(value, e_value, s_value) do { \
    ASSERT_EQ(value.e, e_value); \
    ASSERT_EQ(value.s, s_value); \
} while (0)

static void test_load_fpa(void) {
    Float value;
    PRINT_TEST_NAME();
    SET_FP(value, 1, 1418858818L);
    clear_fpa();
    load_fpa(&value);
    ASSERT_FP_EQ(reg_fpa, 1, 1418858818L);
}

static void test_store_fpa(void) {
    Float value;
    PRINT_TEST_NAME();
    SET_FP(reg_fpa, 1, 1418858818L);
    store_fpa(&value);
    ASSERT_FP_EQ(value, 1, 1418858818L);
}

static void test_clear_fpa(void) {
    PRINT_TEST_NAME();
    SET_FP(reg_fpa, 1, 1418858818L);
    clear_fpa();
    ASSERT_FP_EQ(reg_fpa, 0, 0);
}

static void test_fp_is_zero(void) {
    int result;
    PRINT_TEST_NAME();
    SET_FP(reg_fpa, 1, 1418858818L);
    result = fpa_is_zero();
    ASSERT_EQ(result, 0);
    SET_FP(reg_fpa, 0, 0L);
    result = fpa_is_zero();
    ASSERT_EQ(result, 1);
    SET_FP(reg_fpa, 1, 0L);
    result = fpa_is_zero();
    ASSERT_EQ(result, 1);
}

static void test_fneg(void) {
    PRINT_TEST_NAME();
    SET_FP(reg_fpa, 1, 1418858818L);
    fneg();
    ASSERT_FP_EQ(reg_fpa, 1, -1418858818L);
    fneg();
    ASSERT_FP_EQ(reg_fpa, 1, 1418858818L);
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
    SET_FP(value, 1, 1418858818L);
    swap_fpa(&value);
    ASSERT_FP_EQ(reg_fpa, 1, 1418858818L);
    ASSERT_FP_EQ(value, 0, 0);
}

static void test_int_to_fp(void) {
    PRINT_TEST_NAME();
    // 0
    int_to_fp(0);
    ASSERT_FP_EQ(reg_fpa, 0, 0);
    // 100
    int_to_fp(100);
    ASSERT_FP_EQ(reg_fpa, 0, 100);
    // 1000
    int_to_fp(1000);
    ASSERT_FP_EQ(reg_fpa, 0, 1000);
    // -1
    int_to_fp(-1);
    ASSERT_FP_EQ(reg_fpa, 0, -1);
    // -1000
    int_to_fp(-1000);
    ASSERT_FP_EQ(reg_fpa, 0, -1000);
    // 32767
    int_to_fp(32767);
    ASSERT_FP_EQ(reg_fpa, 0, 32767);
    // -32768
    int_to_fp((int)-32768L);
    ASSERT_FP_EQ(reg_fpa, 0, -32768L);
}

static void test_truncate_fp_to_int(void) {
    char err;
    int* int_value_ptr = (int*)((char*)&reg_fpa + offsetof(Float, s));

    PRINT_TEST_NAME();

    // 0
    SET_FP(reg_fpa, 0, 0);
    err = truncate_fp_to_int();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(*int_value_ptr, 0);
    // 10 as 10E+0
    SET_FP(reg_fpa, 0, 10);
    err = truncate_fp_to_int();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(*int_value_ptr, 10);
    // 10 as 1E+1
    SET_FP(reg_fpa, 1, 1);
    err = truncate_fp_to_int();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(*int_value_ptr, 10);
    // 10 as 100E-1
    SET_FP(reg_fpa, -1, 100);
    err = truncate_fp_to_int();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(*int_value_ptr, 10);
    // -10
    SET_FP(reg_fpa, 0, -10);
    err = truncate_fp_to_int();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(*int_value_ptr, -10);
    // 3.14159 -> 3
    SET_FP(reg_fpa, -5, 314159);
    err = truncate_fp_to_int();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(*int_value_ptr, 3);
    // 32767
    SET_FP(reg_fpa, 0, 32767);
    err = truncate_fp_to_int();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(*int_value_ptr, 32767);
    // -32768
    SET_FP(reg_fpa, 0, (int)-32768L);
    err = truncate_fp_to_int();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(*int_value_ptr, (int)-32768L);
    // 100000 -> overflow
    SET_FP(reg_fpa, 5, 1);
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
    SET_FP(reg_fpa, 0, 0);
    call_fp_to_string();
    ASSERT_STRING_EQ(buffer, "0");
    // 100
    SET_FP(reg_fpa, 0, 100);
    call_fp_to_string();
    ASSERT_STRING_EQ(buffer, "100");
    // -100
    SET_FP(reg_fpa, 0, -100);
    call_fp_to_string();
    ASSERT_STRING_EQ(buffer, "-100");
    // 2E2 (should be 200 since value is in printable range)
    SET_FP(reg_fpa, 2, 2);
    call_fp_to_string();
    ASSERT_STRING_EQ(buffer, "200");
    // 3.14159
    SET_FP(reg_fpa, -5, 314159);
    call_fp_to_string();
    ASSERT_STRING_EQ(buffer, "3.14159");
    // 0.0314159
    SET_FP(reg_fpa, -7, 314159);
    call_fp_to_string();
    ASSERT_STRING_EQ(buffer, "0.0314159");
    // 6.0221409E23
    SET_FP(reg_fpa, 16, 60221409);
    call_fp_to_string();
    ASSERT_STRING_EQ(buffer, "6.0221409E23");
    // 0.00729734813
    SET_FP(reg_fpa, -11, 729734813);
    call_fp_to_string();
    ASSERT_STRING_EQ(buffer, "7.29734813E-3");

    // Exponent edge cases
    // +/- 1E9 should print without E
    // +/- 1E10 should print in scientific
    SET_FP(reg_fpa, 9, 1);
    call_fp_to_string();
    ASSERT_STRING_EQ(buffer, "1000000000");
    SET_FP(reg_fpa, 9, -1);
    call_fp_to_string();
    ASSERT_STRING_EQ(buffer, "-1000000000");
    SET_FP(reg_fpa, 10, 1);
    call_fp_to_string();
    ASSERT_STRING_EQ(buffer, "1E10");
    SET_FP(reg_fpa, 10, -1);
    call_fp_to_string();
    ASSERT_STRING_EQ(buffer, "-1E10");
    // Test for logic that removes trailing zeros
    SET_FP(reg_fpa, -2, 1000);
    call_fp_to_string();
    ASSERT_STRING_EQ(buffer, "10");
    SET_FP(reg_fpa, -6, 1000);
    call_fp_to_string();
    ASSERT_STRING_EQ(buffer, "0.001");
    SET_FP(reg_fpa, 15, 100);
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
    ASSERT_FP_EQ(reg_fpa, 0, 0);
    ASSERT_EQ(bp, 1);
    err = call_string_to_fp("0.0");
    ASSERT_EQ(err, 0);
    ASSERT_FP_EQ(reg_fpa, -1, 0);
    ASSERT_EQ(bp, 3);
    err = call_string_to_fp(".0");
    ASSERT_EQ(err, 0);
    ASSERT_FP_EQ(reg_fpa, -1, 0);
    ASSERT_EQ(bp, 2);
    err = call_string_to_fp("0.");
    ASSERT_EQ(err, 0);
    ASSERT_FP_EQ(reg_fpa, 0, 0);
    ASSERT_EQ(bp, 2);
    err = call_string_to_fp(".");
    ASSERT_EQ(err, 0);
    ASSERT_FP_EQ(reg_fpa, 0, 0);
    ASSERT_EQ(bp, 1);
    // 100
    err = call_string_to_fp("100");
    ASSERT_EQ(err, 0);
    ASSERT_FP_EQ(reg_fpa, 0, 100);
    ASSERT_EQ(bp, 3);
    // -100
    err = call_string_to_fp("-100");
    ASSERT_EQ(err, 0);
    ASSERT_FP_EQ(reg_fpa, 0, -100);
    ASSERT_EQ(bp, 4);
    // 2E2
    err = call_string_to_fp("2E2");
    ASSERT_EQ(err, 0);
    ASSERT_FP_EQ(reg_fpa, 2, 2);
    ASSERT_EQ(bp, 3);
    // 3.14159
    err = call_string_to_fp("3.14159");
    ASSERT_EQ(err, 0);
    ASSERT_FP_EQ(reg_fpa, -5, 314159);
    ASSERT_EQ(bp, 7);
    // 6.0221409E23
    err = call_string_to_fp("6.0221409E23");
    ASSERT_EQ(err, 0);
    ASSERT_FP_EQ(reg_fpa, 16, 60221409);
    ASSERT_EQ(bp, 12);
    // Significand limits
    err = call_string_to_fp("2147483647");
    ASSERT_EQ(err, 0);
    ASSERT_FP_EQ(reg_fpa, 0, LONG_MAX);
    ASSERT_EQ(bp, 10);
    err = call_string_to_fp("-2147483648");
    ASSERT_EQ(err, 0);
    ASSERT_FP_EQ(reg_fpa, 0, LONG_MIN);
    ASSERT_EQ(bp, 11);
    // Exponent limits
    err = call_string_to_fp("1E127");
    ASSERT_EQ(err, 0);
    ASSERT_FP_EQ(reg_fpa, 127, 1);
    ASSERT_EQ(bp, 5);
    err = call_string_to_fp("1E-127");
    ASSERT_EQ(err, 0);
    ASSERT_FP_EQ(reg_fpa, -127, 1);
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
    ASSERT_FP_EQ(reg_fpa, 0, 10);
    ASSERT_EQ(bp, 2);
    err = call_string_to_fp("10X");
    ASSERT_EQ(err, 0);
    ASSERT_FP_EQ(reg_fpa, 0, 10);
    ASSERT_EQ(bp, 2);
    err = call_string_to_fp("10. ");
    ASSERT_EQ(err, 0);
    ASSERT_FP_EQ(reg_fpa, 0, 10);
    ASSERT_EQ(bp, 3);
    err = call_string_to_fp("10.X");
    ASSERT_EQ(err, 0);
    ASSERT_FP_EQ(reg_fpa, 0, 10);
    ASSERT_EQ(bp, 3);
    err = call_string_to_fp("10E");
    ASSERT_EQ(err, 0);
    ASSERT_FP_EQ(reg_fpa, 0, 10);
    ASSERT_EQ(bp, 3);
    err = call_string_to_fp("10E ");
    ASSERT_EQ(err, 0);
    ASSERT_FP_EQ(reg_fpa, 0, 10);
    ASSERT_EQ(bp, 3);
    err = call_string_to_fp("10EX");
    ASSERT_EQ(err, 0);
    ASSERT_FP_EQ(reg_fpa, 0, 10);
    ASSERT_EQ(bp, 3);
    err = call_string_to_fp("10E1 ");
    ASSERT_EQ(err, 0);
    ASSERT_FP_EQ(reg_fpa, 1, 10);
    ASSERT_EQ(bp, 4);
    err = call_string_to_fp("10E-1 ");
    ASSERT_EQ(err, 0);
    ASSERT_FP_EQ(reg_fpa, -1, 10);
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
    SET_FP(reg_fpa, 0, 0);
    SET_FP(value, 0, 0);
    fadd(&value);
    ASSERT_FP_EQ(reg_fpa, 0, 0);
    // 1 + 1
    SET_FP(reg_fpa, 0, 1);
    SET_FP(value, 0, 1);
    fadd(&value);
    ASSERT_FP_EQ(reg_fpa, 0, 2);
    // 1 + 1E1
    SET_FP(reg_fpa, 0, 1);
    SET_FP(value, 1, 1);
    fadd(&value);
    ASSERT_FP_EQ(reg_fpa, 0, 11);
    // 1E1 + 1
    SET_FP(reg_fpa, 1, 1);
    SET_FP(value, 0, 1);
    fadd(&value);
    ASSERT_FP_EQ(reg_fpa, 0, 11);
    // 1 + 3.14159
    SET_FP(reg_fpa, 0, 1);
    SET_FP(value, -5, 314159);
    fadd(&value);
    ASSERT_FP_EQ(reg_fpa, -5, 414159);
    // 1 + -1
    SET_FP(reg_fpa, 0, 1);
    SET_FP(value, 0, -1);
    fadd(&value);
    ASSERT_FP_EQ(reg_fpa, 0, 0);
    // 1E1 + -1
    SET_FP(reg_fpa, 1, 1);
    SET_FP(value, 0, -1);
    fadd(&value);
    ASSERT_FP_EQ(reg_fpa, 0, 9);
    // 1 + -1E1
    SET_FP(reg_fpa, 0, 1);
    SET_FP(value, 1, -1);
    fadd(&value);
    ASSERT_FP_EQ(reg_fpa, 0, -9);
    // // LONG_MAX + 1
    // SET_FP(reg_fpa, 0, LONG_MAX);
    // SET_FP(value, 0, 1);
    // fadd(&value);
    // ASSERT_FP_EQ(reg_fpa, 1, -9);
}

static void test_fsub(void) {
    Float value;

    PRINT_TEST_NAME();

    // Don't need many fsub tests since it just negates its argument and calls fadd.

    // 3.14159 - 1.14159 = 2
    SET_FP(reg_fpa, -5, 314159);
    SET_FP(value, -5, 114159);
    fsub(&value);
    ASSERT_FP_EQ(reg_fpa, -5, 200000);
    // -100 - 2.5 = -102.5
    SET_FP(reg_fpa, 2, -1);
    SET_FP(value, -1, 25);
    fsub(&value);
    ASSERT_FP_EQ(reg_fpa, -1, -1025);
}

static void test_fmul(void) {
    Float value;

    PRINT_TEST_NAME();

    // 0 * 0 = 0
    SET_FP(reg_fpa, 0, 0);
    SET_FP(value, 0, 0);
    fmul(&value);
    ASSERT_FP_EQ(reg_fpa, 0, 0);
    // 1 * 1 = 1
    SET_FP(reg_fpa, 0, 1);
    SET_FP(value, 0, 1);
    fmul(&value);
    ASSERT_FP_EQ(reg_fpa, 0, 1);
    // 1E1 * 1 = 1E1
    SET_FP(reg_fpa, 1, 1);
    SET_FP(value, 0, 1);
    fmul(&value);
    ASSERT_FP_EQ(reg_fpa, 1, 1);
    // 1,000,000,000 * 1,000,000,000
    SET_FP(reg_fpa, 0, 1000000000);
    SET_FP(value, 0, 1000000000);
    fmul(&value);
    ASSERT_FP_EQ(reg_fpa, 9, 1000000000);
    // 3.14159 * 1E5 = 314159
    SET_FP(reg_fpa, -5, 314159);
    SET_FP(value, 5, 1);
    fmul(&value);
    ASSERT_FP_EQ(reg_fpa, 0, 314159);
    // 1 * -1 = -1
    SET_FP(reg_fpa, 0, 1);
    SET_FP(value, 0, -1);
    fmul(&value);
    ASSERT_FP_EQ(reg_fpa, 0, -1);
    // -1 * 1 = -1
    SET_FP(reg_fpa, 0, -1);
    SET_FP(value, 0, 1);
    fmul(&value);
    ASSERT_FP_EQ(reg_fpa, 0, -1);
    // -1 * -1 = 1
    SET_FP(reg_fpa, 0, -1);
    SET_FP(value, 0, -1);
    fmul(&value);
    ASSERT_FP_EQ(reg_fpa, 0, 1);
    // 3.14159 * 3.14159
    // TODO: should round up not truncate
    SET_FP(reg_fpa, -5, 314159);
    SET_FP(value, -5, 314159);
    fmul(&value);
    ASSERT_FP_EQ(reg_fpa, -8, 986958772);
}

static void test_fdiv(void) {
    Float value;

    PRINT_TEST_NAME();
    
    // 1 / 1 = 1
    SET_FP(reg_fpa, 0, 1);
    SET_FP(value, 0, 1);
    fdiv(&value);
    ASSERT_FP_EQ(reg_fpa, 0, 1);
    
    SET_FP(reg_fpa, 0, 10);
    SET_FP(value, 0, 1);
    fdiv(&value);
    ASSERT_FP_EQ(reg_fpa, 0, 10);
    
    // 1000000000 / 1 = 1000000000
    SET_FP(reg_fpa, 0, 1000000000);
    SET_FP(value, 0, 1);
    fdiv(&value);
    ASSERT_FP_EQ(reg_fpa, 0, 1000000000);
    
    // 8 / 2 = 4
    SET_FP(reg_fpa, 0, 8);
    SET_FP(value, 0, 2);
    fdiv(&value);
    ASSERT_FP_EQ(reg_fpa, 0, 4);
    
    // 3.14159 / 1 = 3.14159
    SET_FP(reg_fpa, -5, 314159);
    SET_FP(value, 0, 1);
    fdiv(&value);
    ASSERT_FP_EQ(reg_fpa, -5, 314159);
    
    // 3.14159 / 1E1 = 0.314159
    SET_FP(reg_fpa, -5, 314159);
    SET_FP(value, 1, 1);
    fdiv(&value);
    ASSERT_FP_EQ(reg_fpa, -6, 314159);
    
    // 3 / 10 = 0.3
    SET_FP(reg_fpa, 0, 3);
    SET_FP(value, 0, 10);
    fdiv(&value);
    ASSERT_FP_EQ(reg_fpa, -1, 3);
    
    // 3.14159 / 10 = 0.314159
    SET_FP(reg_fpa, -5, 314159);
    SET_FP(value, 0, 10);
    fdiv(&value);
    ASSERT_FP_EQ(reg_fpa, -6, 314159);
}

int main(void) {
    initialize_target();
    test_load_fpa();
    test_store_fpa();
    test_clear_fpa();
    test_fp_is_zero();
    test_fneg();
    test_char_to_digit();
    test_swap_fpa();
    test_int_to_fp();
    test_truncate_fp_to_int();
    test_fp_to_string();
    test_string_to_fp();
    test_fadd();
    test_fsub();
    test_fmul();
    test_fdiv();
    return 0;
}
