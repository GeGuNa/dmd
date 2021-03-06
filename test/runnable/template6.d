// This is a copy of the engine here:
//   https://www.digitalmars.com/d/2.0/templates-revisited.html
// which is a cut down version of the file here:
//   http://www.dsource.org/projects/ddl/browser/trunk/meta/regex.d
// which has this copyright notice:
/+
    Copyright (c) 2005 Eric Anderton

    Permission is hereby granted, free of charge, to any person
    obtaining a copy of this software and associated documentation
    files (the "Software"), to deal in the Software without
    restriction, including without limitation the rights to use,
    copy, modify, merge, publish, distribute, sublicense, and/or
    sell copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following
    conditions:

    The above copyright notice and this permission notice shall be
    included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
    OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
    NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
    HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
    OTHER DEALINGS IN THE SOFTWARE.
+/


const int testFail = -1;

/**
 * Compile pattern[] and expand to a custom generated function
 * that will take a string str[] and apply the regular expression
 * to it, returning an array of matches.
 */

template regexMatch(string pattern)
{
    string[] regexMatch(string str)
    {
        string[] results;
        int result = regexCompile!(pattern).fn(str);
        if(result != testFail && result > 0){
            results ~= str[0..result];
        }
        return results;
    }
}

/******************************
 * The testXxxx() functions are custom generated by templates
 * to match each predicate of the regular expression.
 *
 * Params:
 *      string str      the input string to match against
 *
 * Returns:
 *      testFail        failed to have a match
 *      n >= 0          matched n characters
 */

/// Always match
template testEmpty()
{
    int testEmpty(string str) { return 0; }
}

/// Match if testFirst(str) and testSecond(str) match
template testUnion(alias testFirst,alias testSecond,string key)
{
    int testUnion(string str)
    {
        int result = testFirst(str);
        if(result != testFail){
            int nextResult = testSecond(str[result..$]);
            if(result != testFail)
                return result + nextResult;
        }
        return testFail;
    }
}

/// Match if first part of str[] matches text[]
template testText(string text)
{
    int testText(string str)
    {
        if (str.length &&
            text.length <= str.length &&
            str[0..text.length] == text
           )
            return text.length;
        return testFail;
    }
}

/// Match if testPredicate(str) matches 0 or more times
template testZeroOrMore(alias testPredicate,string key)
{
    int testZeroOrMore(string str)
    {
        if(str.length == 0) return 0;
        int result = testPredicate(str);
        if(result != testFail){
            int nextResult = .testZeroOrMore!(testPredicate,key)(str[result..$]);
            if(nextResult != testFail)
                return result + nextResult;
            return result;
        }
        return 0;
    }
}

/// Match if term1[0] <= str[0] <= term2[0]
template testRange(string term1,string term2)
{
    int testRange(string str)
    {
        if(str.length && str[0] >= term1[0] && str[0] <= term2[0])
            return 1;
        return testFail;
    }
}

/// Match if ch[0]==str[0]
template testChar(string ch)
{
    int testChar(string str)
    {
        if(str.length && str[0] == ch[0])
            return 1;
        return testFail;
    }
}

/// Match if str[0] is a word character
template testWordChar()
{
    int testWordChar(string str)
    {
        if(str.length &&
           (
            (str[0] >= 'a' && str[0] <= 'z') ||
            (str[0] >= 'A' && str[0] <= 'Z') ||
            (str[0] >= '0' && str[0] <= '9') ||
            str[0] == '_'
           )
          )
        {
            return 1;
        }
        return testFail;
    }
}

/*****************************************************/

/**
 * Returns the front of pattern[] up until the end or a special character.
 */

template parseTextToken(string pattern){
    static if(pattern.length > 0){
        static if(isSpecial!(pattern)){
            const string parseTextToken="";
        }
        else{
            const string parseTextToken = pattern[0] ~ parseTextToken!(pattern[1..$]);
        }
    }
    else{
        const string parseTextToken="";
    }
}

/**
 * Parses pattern[] up to and including terminator.
 * Returns:
 *      token[]         everything up to terminator.
 *      consumed        number of characters in pattern[] parsed
 */
template parseUntil(string pattern,char terminator,bool fuzzy=false){
    static if(pattern.length > 0){
        static if(pattern[0] == '\\'){
            static if(pattern.length > 1){
                const string nextSlice = pattern[2 .. $];
                alias parseUntil!(nextSlice,terminator,fuzzy) next;
                const string token = pattern[0 .. 2] ~ next.token;
                const uint consumed = next.consumed+2;
            }
            else{
                pragma(msg,"Error: expected character to follow \\");
                static assert(false);
            }
        }
        else static if(pattern[0] == terminator){
            const string token="";
            const uint consumed = 1;
        }
        else{
            const string nextSlice = pattern[1 .. $];
            alias parseUntil!(nextSlice,terminator,fuzzy) next;
            const string token = pattern[0] ~ next.token;
            const uint consumed = next.consumed+1;
        }
    }
    else static if(fuzzy){
        const string token = "";
        const uint consumed = 0;
    }
    else{
        pragma(msg,"Error: exptected " ~ terminator ~ " to terminate group expression");
        static assert(false);
    }
}

/**
 * Parse contents of character class.
 * Params:
 *      pattern[]  rest of pattern to compile
 * Output:
 *      fn         generated function
 *      consumed   number of characters in pattern[] parsed
 */

template regexCompileCharClass2(string pattern){
    static if(pattern.length > 0){
        static if(pattern.length > 1){
            static if(pattern[1] == '-'){
                static if(pattern.length > 2){
                    alias testRange!(pattern[0..1], pattern[2..3]) termFn;
                    const uint thisConsumed = 3;
                    const string remaining = pattern[3 .. $];
                }
                else{ // length is 2
                    pragma(msg,"Error: expected character following '-' in character class");
                    static assert(false);
                }
            }
            else{ // not '-'
                alias testChar!(pattern[0..1]) termFn;
                const uint thisConsumed = 1;
                const string remaining = pattern[1 .. $];
            }
        }
        else{
            alias testChar!(pattern[0..1]) termFn;
            const uint thisConsumed = 1;
            const string remaining = pattern[1 .. $];
        }

        static if(remaining.length > 0){
            static if(remaining[0] != ']'){
                alias regexCompileCharClass2!(remaining) next;
                alias testOr!(termFn,next.fn,remaining) fn;
                const uint consumed = next.consumed + thisConsumed;
            }
            else{
                alias termFn fn;
                const uint consumed = thisConsumed;
            }
        }
        else{
            alias termFn fn;
            const uint consumed = thisConsumed;
        }
    }
    else{
        alias testEmpty!() fn;
        const uint consumed = 0;
    }
}

/**
 * At start of character class. Compile it.
 * Params:
 *      pattern[]  rest of pattern to compile
 * Output:
 *      fn         generated function
 *      consumed   number of characters in pattern[] parsed
 */

template regexCompileCharClass(string pattern){
    static if(pattern.length > 0){
        static if(pattern[0] == ']'){
            alias testEmpty!() fn;
            const uint consumed = 0;
        }
        else{
            alias regexCompileCharClass2!(pattern) charClass;
            alias charClass.fn fn;
            const uint consumed = charClass.consumed;
        }
    }
    else{
        pragma(msg,"Error: expected closing ']' for character class");
        static assert(false);
    }
}

/**
 * Look for and parse '*' postfix.
 * Params:
 *      test       function compiling regex up to this point
 *      token[]    the part of original pattern that the '*' is a postfix of
 *      pattern[]  rest of pattern to compile
 * Output:
 *      fn         generated function
 *      consumed   number of characters in pattern[] parsed
 */

template regexCompilePredicate(alias test,string token,string pattern){
    static if(pattern.length > 0){
        static if(pattern[0] == '*'){
            alias testZeroOrMore!(test,token) fn;
            const uint consumed = 1;
        }
        else{
            alias test fn;
            const uint consumed = 0;
        }
    }
    else{
        alias test fn;
        const uint consumed = 0;
    }
}

/**
 * Parse escape sequence.
 * Params:
 *      pattern[]  rest of pattern to compile
 * Output:
 *      fn         generated function
 *      consumed   number of characters in pattern[] parsed
 */

template regexCompileEscape(string pattern){
    static if(pattern.length > 0){
        static if(pattern[0] == 's'){
            // whitespace char
            alias testRange!("\x00","\x20") fn;
        }
        else static if(pattern[0] == 'w'){
            //word char
            alias testWordChar!() fn;
        }
        else{
            alias testChar!(pattern[0 .. 1]) fn;
        }
        const uint consumed = 1;
    }
    else{
        pragma(msg,"Error: expected char following '\\'");
        static assert(false);
    }
}

/**
 * Parse and compile regex represented by pattern[].
 * Params:
 *      pattern[]  rest of pattern to compile
 * Output:
 *      fn         generated function
 */

template regexCompile(string pattern)
{
    static if(pattern.length > 0){
        static if(pattern[0] == '['){
            const string charClassToken = parseUntil!(pattern[1 .. $],']').token;
            alias regexCompileCharClass!(charClassToken) charClass;
            const string token = pattern[0 .. charClass.consumed+2];
            const string next = pattern[charClass.consumed+2 .. $];
            alias charClass.fn test;
        }
        else static if(pattern[0] == '\\'){
            alias regexCompileEscape!(pattern[1..$]) escapeSequence;
            const string token = pattern[0 .. escapeSequence.consumed+1];
            const string next = pattern[escapeSequence.consumed+1 .. $];
            alias escapeSequence.fn test;
        }
        else{
            const string token = parseTextToken!(pattern);
            static assert(token.length > 0);
            const string next = pattern[token.length .. $];
            alias testText!(token) test;
        }

        alias regexCompilePredicate!(test,token,next) term;
        const string remaining = next[term.consumed .. next.length];

        static if(remaining.length > 0){
            alias testUnion!(term.fn,regexCompile!(remaining).fn,remaining) fn;
        }
        else{
            alias term.fn fn;
        }
    }
    else{
        alias testEmpty!() fn;
    }
}

/// Utility function for parsing
template isSpecial(string pattern)
{
    static if(
        pattern[0] == '*' ||
        pattern[0] == '+' ||
        pattern[0] == '?' ||
        pattern[0] == '.' ||
        pattern[0] == '[' ||
        pattern[0] == '{' ||
        pattern[0] == '(' ||
        pattern[0] == '$' ||
        pattern[0] == '^' ||
        pattern[0] == '\\'
    ){
        const bool isSpecial = true;
    }
    else{
        const bool isSpecial = false;
    }
}




int main()
{
    auto exp = &regexMatch!(r"[a-z]*\s*\w*");
    string[] m = exp("hello    world");
    assert(m.length == 1);
    assert(m[0] == "hello    world");
    return 0;
}
