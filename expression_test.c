#include "test.h"

static void set_line(const char* data, size_t length) {
    line_buffer.number = 0;
    line_buffer.next_line_offset = (char)(length + offsetof(Line, data));
    memcpy(line_buffer.data, data, length);
    line_ptr = &line_buffer;
    lp = (char)offsetof(Line, data);
}

static void test_evaluate_expression(void) {
    char err;
    int result;

    const char line_data_1[] = { TOKEN_NUM, 0x01, 0x00, TOKEN_OP | OP_ADD, TOKEN_NUM, 0x02, 0x00, TOKEN_NO_VALUE };

    set_line(line_data_1, sizeof line_data_1);
    err = evaluate_expression();
    ASSERT_EQ(err, 0);
    result = pop_value();
    ASSERT_EQ(result, 3);
}

int main(void) {
    initialize_target();
    initialize_program();
    test_evaluate_expression();
    return 0;
}
