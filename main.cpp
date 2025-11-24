#include <iostream>
#include <string>
#include <vector>
#include <algorithm>
#include <cctype>
#include <sstream>
#include <limits>
#include <set>

using namespace std;

// --- 모스 부호 데이터 정의 ---
struct MorseEntry {
    char character;
    const char* code;
};

const MorseEntry MORSE_DEFINITIONS[] = {
    {'A', ".-"}, {'B', "-..."}, {'C', "-.-."}, {'D', "-.."}, {'E', "."},
    {'F', "..-."}, {'G', "--."}, {'H', "...."}, {'I', ".."}, {'J', ".---"},
    {'K', "-.-"}, {'L', ".-.."}, {'M', "--"}, {'N', "-."}, {'O', "---"},
    {'P', ".--."}, {'Q', "--.-"}, {'R', ".-."}, {'S', "..."}, {'T', "-"},
    {'U', "..-"}, {'V', "...-"}, {'W', ".--"}, {'X', "-..-"}, {'Y', "-.--"},
    {'Z', "--.."},
    {'1', ".----"}, {'2', "..---"}, {'3', "...--"}, {'4', "....-"}, {'5', "....."},
    {'6', "-...."}, {'7', "--..."}, {'8', "---.."}, {'9', "----."}, {'0', "-----"}
};
const int NUM_MORSE_ENTRIES = sizeof(MORSE_DEFINITIONS) / sizeof(MORSE_DEFINITIONS[0]);

// --- Q 부호 정의 ---
const set<string> Q_CODES = {
    "QRA", "QRB", "QRC", "QRD", "QRE", "QRF", "QRG", "QRH", "QRI", "QRJ", "QRK", "QRL", "QRM", "QRN", "QRO", "QRP", "QRQ", "QRR", "QRS", "QRT", "QRU", "QRV", "QRW", "QRX", "QRY", "QRZ",
    "QSA", "QSB", "QSC", "QSD", "QSE", "QSF", "QSG", "QSH", "QSI", "QSJ", "QSK", "QSL", "QSM", "QSN", "QSO", "QSP", "QSQ", "QSR", "QSS", "QST", "QSU", "QSV", "QSW", "QSX", "QSY", "QSZ",
    "QTA", "QTB", "QTC", "QTD", "QTE", "QTF", "QTG", "QTH", "QTI", "QTJ", "QTK", "QTL", "QTM", "QTN", "QTO", "QTP", "QTQ", "QTR", "QTS", "QTT", "QTU", "QTV", "QTW", "QTX", "QTY", "QTZ",
    "QUA", "QUB", "QUC", "QUD", "QUE", "QUF", "QUG", "QUH", "QUI", "QUJ", "QUK", "QUL", "QUM", "QUN", "QUO", "QUP", "QUQ", "QUR", "QUS", "QUT", "QUU", "QUV", "QUW", "QUX", "QUY", "QUZ"
};

// --- 노드 구조 정의 ---
struct MorseNode {
    char character;
    MorseNode* dot_child;
    MorseNode* dash_child;

    MorseNode(char c = '\0') : character(c), dot_child(nullptr), dash_child(nullptr) {}
};

// --- 트리 생성 및 구축 ---
MorseNode* build_morse_tree() {
    MorseNode* root = new MorseNode();

    for (int i = 0; i < NUM_MORSE_ENTRIES; ++i) {
        char character = MORSE_DEFINITIONS[i].character;
        const char* morse_code = MORSE_DEFINITIONS[i].code;
        MorseNode* current_node = root;

        for (const char* symbol = morse_code; *symbol != '\0'; ++symbol) {
            if (*symbol == '.') {
                if (current_node->dot_child == nullptr) {
                    current_node->dot_child = new MorseNode();
                }
                current_node = current_node->dot_child;
            } else if (*symbol == '-') {
                if (current_node->dash_child == nullptr) {
                    current_node->dash_child = new MorseNode();
                }
                current_node = current_node->dash_child;
            }
        }
        current_node->character = character;
    }

    return root;
}

void delete_morse_tree(MorseNode* node) {
    if (node == nullptr) return;
    delete_morse_tree(node->dot_child);
    delete_morse_tree(node->dash_child);
    delete node;
}

// --- 단일 모스 부호 문자열을 문자로 변환하는 헬퍼 함수 ---
char morse_segment_to_char(MorseNode* root, const string& segment) {
    MorseNode* curr = root;
    for (char c : segment) {
        if (c == '.') curr = curr->dot_child;
        else if (c == '-') curr = curr->dash_child;
        else return '\0';

        if (curr == nullptr) return '\0';
    }
    return curr->character;
}

// --- 공백 없는 Q 부호 스트림 해석 (Spaceless Decoding) ---
// 입력: --.-.-.- (QRT)
// 로직: 앞의 4자리(--.-)는 Q로 고정하고, 나머지 문자열을 두 개의 유효한 문자로 분할 시도
string try_decode_spaceless_q(MorseNode* root, const string& buffer) {
    // Q 부호의 최소 길이는 Q(4) + E(1) + E(1) = 6
    // 최대 길이는 Q(4) + 0(5) + 0(5) = 14 (숫자 포함 시) 또는 알파벳만 하면 Q(4)+Y(4)+Y(4)=12
    if (buffer.length() < 6) return "";

    // 1. Prefix가 Q(--.-)인지 확인
    string q_sig = "--.-";
    if (buffer.substr(0, 4) != q_sig) return "";

    // 2. 나머지 문자열 추출
    string remainder = buffer.substr(4);
    int rem_len = remainder.length();

    // 나머지를 두 개의 유효한 모스 부호로 나눌 수 있는지 모든 지점에서 분할 시도
    // 예: remainder = ".-.-" -> split at 1: "."(E) / "-.-"(K) -> QEK?
    //                        -> split at 2: ".-"(A) / ".-"(A) -> QAA?
    //                        -> split at 3: ".-."(R) / "-"(T) -> QRT? (Valid!)

    for (int i = 1; i < rem_len; ++i) {
        string part1 = remainder.substr(0, i);
        string part2 = remainder.substr(i);

        char c1 = morse_segment_to_char(root, part1);
        char c2 = morse_segment_to_char(root, part2);

        if (c1 != '\0' && c2 != '\0') {
            string potential_code = "Q";
            potential_code += c1;
            potential_code += c2;

            // 유효한 Q 부호 목록에 있는지 확인
            if (Q_CODES.count(potential_code)) {
                return potential_code;
            }
        }
    }

    return "";
}

int main() {
    MorseNode* morse_tree_root = build_morse_tree();

    cout << "============================================" << endl;
    cout << "    실시간 모스 부호 입력 시뮬레이션    " << endl;
    cout << "============================================" << endl;
    cout << "* 입력 방법: '.' 또는 '-'를 한 글자씩 입력하고 Enter를 누르세요." << endl;
    cout << "* 기능 설명:" << endl;
    cout << "  1. 5글자 이하: 일반 입력 대기" << endl;
    cout << "  2. 6글자 이상: 자동으로 Q 부호 판별 모드 진입" << endl;
    cout << "     - Q 부호 매칭 성공 시: 즉시 결과 출력" << endl;
    cout << "     - Q 부호 아님 판명 시: 버퍼 폐기" << endl;
    cout << "* 종료하려면 'exit' 입력" << endl;
    cout << "--------------------------------------------" << endl;

    string input_segment;
    string current_buffer = "";

    while (true) {
        cout << "\n입력 (현재 버퍼: " << current_buffer << "): ";
        cin >> input_segment;

        if (input_segment == "exit") break;

        // 유효성 검사 (점, 선 이외 무시)
        for (char c : input_segment) {
            if (c == '.' || c == '-') {
                current_buffer += c;
            }
        }

        // --- 로직 분기 ---

        // Case 1: 버퍼 길이가 6 이상인 경우 (Q 부호 예측 로직 발동)
        if (current_buffer.length() >= 6) {
            // 1. Q 부호(Q로 시작)가 아니면 즉시 폐기
            if (current_buffer.substr(0, 4) != "--.-") {
                 cout << ">> [SYSTEM] 길이 6 이상이나 Q(--.-)로 시작하지 않음 -> 버퍼 폐기." << endl;
                 current_buffer = "";
                 continue;
            }

            // 2. Q 부호 해독 시도
            string detected_q = try_decode_spaceless_q(morse_tree_root, current_buffer);

            if (!detected_q.empty()) {
                // 성공: QRT 등 발견
                cout << ">> [SUCCESS] Q 부호 감지됨: " << detected_q << endl;
                current_buffer = ""; // 출력 후 초기화
            } else {
                // 실패: 아직 완성되지 않았거나 잘못된 입력
                // Q 부호의 이론적 최대 길이(약 13~14)를 넘어가면 더 이상 기다리지 않고 폐기
                if (current_buffer.length() > 13) {
                    cout << ">> [FAIL] 유효한 Q 부호를 찾을 수 없음 (길이 초과) -> 버퍼 폐기." << endl;
                    current_buffer = "";
                } else {
                    cout << ">> [INFO] Q 부호 패턴 분석 중... (추가 입력 대기)" << endl;
                }
            }
        }
        // Case 2: 버퍼 길이가 5 이하인 경우 (일반 문자 대기)
        else {
            // 5글자 이하에서는 스페이스바(여기서는 시뮬레이션 한계로 구현 생략)가
            // 들어오지 않는 이상 계속 버퍼링하며 대기합니다.
            // 만약 사용자가 여기서 끊고 싶다면 별도의 구분 신호를 주어야 하지만,
            // 요청하신 로직은 "길이가 길어지면 Q부호로 간주"이므로 계속 쌓습니다.
        }
    }

    delete_morse_tree(morse_tree_root);
    return 0;
}
