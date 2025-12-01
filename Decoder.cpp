#include <bits/stdc++.h>
using namespace std;

// 일반 모스부호
unordered_map<string,char> morse = {
    {".-", 'A'},   {"-...", 'B'}, {"-.-.", 'C'}, {"-..", 'D'},
    {".", 'E'},    {"..-.", 'F'}, {"--.", 'G'},  {"....", 'H'},
    {"..", 'I'},   {".---", 'J'}, {"-.-", 'K'},  {".-..", 'L'},
    {"--", 'M'},   {"-.", 'N'},   {"---", 'O'},  {".--.", 'P'},
    {"--.-", 'Q'}, {".-.", 'R'},  {"...", 'S'},  {"-", 'T'},
    {"..-", 'U'},  {"...-", 'V'}, {".--", 'W'},  {"-..-", 'X'},
    {"-.--", 'Y'}, {"--..", 'Z'},
    {"-----", '0'}, {".----", '1'}, {"..---", '2'}, {"...--", '3'},
    {"....-", '4'}, {".....", '5'}, {"-....", '6'}, {"--...", '7'},
    {"---..", '8'}, {"----.", '9'}
};

// Q prefix (고정 6자리)
unordered_map<string, char> Qprefix = {
    {"--.---", 'T'}, // QT
    {"--.-..", 'U'}  // QU
    // QS 필요시 추가
};

// Q suffix (3자리 단위)
unordered_map<char, unordered_map<string,char>> Qsuffix = {
    {'T', {
        {".-.", 'C'},   // QTC
        {"..-", 'X'},   // QTX
        // 필요시 확장
    }},
    {'U', {
        {"..-", 'U'},   // QU( U )
        {".--", 'W'},   // QU( W )
        // 예제 기반
    }}
};

// 일반 모스 greedy decode
string greedy(const string& s) {
    int n = s.size();
    int i = 0;
    string res;
    while (i<n) {
        bool ok=false;
        for (int len=1; len<=5 && i+len<=n; len++) {
            string sub = s.substr(i,len);
            if (morse.count(sub)) {
                res.push_back(morse[sub]);
                i += len;
                ok=true;
                break;
            }
        }
        if (!ok) {
            res.push_back('?');
            break;
        }
    }
    return res;
}

string decodeToken(const string& s) {
    if (s.size() < 6) {
        if (morse.count(s)) return string(1,morse[s]);
        return "?";
    }

    string pref = s.substr(0,6);

    if (Qprefix.count(pref)) {
        char type = Qprefix[pref];

        // QT = 뒤 3자리
        // QU = 뒤 6자리 (예제 기준)
        if (type=='T') {
            if (s.size() < 9) return "?";
            string suf = s.substr(6,3); // 정확히 3자리

            if (Qsuffix[type].count(suf)) {
                char alpha = Qsuffix[type][suf];
                string rest = s.substr(9);
                return string("QT") + alpha + greedy(rest);
            }
            return "?";
        }
        else if (type=='U') {
            if (s.size() < 12) return "?";
            string suf1 = s.substr(6,3);
            string suf2 = s.substr(9,3);
            if (Qsuffix[type].count(suf1) && Qsuffix[type].count(suf2)) {
                char alpha = Qsuffix[type][suf2]; // 예제 QUW에서 뒤 조각이 최종 알파벳
                string rest = s.substr(12);
                return string("QU") + alpha + greedy(rest);
            }
            return "?";
        }
    }

    // 일반 모스 규칙
    if (s.size() >= 6) return "?";
    if (morse.count(s)) return string(1,morse[s]);
    return "?";
}

int main() {
    ios::sync_with_stdio(false);
    cin.tie(NULL);

    string line;
    getline(cin, line);

    vector<string> tokens;
    string cur;
    int sp=0;

    for (char c : line) {
        if (c==' ') {
            sp++;
            if (sp==1) {
                if (cur.size()) tokens.push_back(cur);
                cur.clear();
            } else if (sp==2) {
                tokens.push_back(" ");
            }
        } else {
            if (sp>=1) sp=0;
            cur.push_back(c);
        }
    }
    if (cur.size()) tokens.push_back(cur);

    string ans;
    for (auto&t : tokens) {
        if (t==" ") ans.push_back(' ');
        else ans += decodeToken(t);
    }
    cout << ans;
}
