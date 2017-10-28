#header
<<
#include <string>
#include <iostream>
using namespace std;

// struct to store information about tokens
struct Attrib {
    string kind;
    string text;
};

// function to fill token information (predeclaration)
void zzcr_attr(Attrib *attr, int type, char *text);

// fields for AST nodes
#define AST_FIELDS string kind; string text;
#include "ast.h"

// macro to create a new AST node (and function predeclaration)
#define zzcr_ast(as,attr,ttype,textt) as=createASTnode(attr,ttype,textt)
AST* createASTnode(Attrib* attr, int ttype, char *textt);
>>

<<
#include <cstdlib>
#include <cmath>
#include <map>
#include <vector>
#include <string>
#include <exception>
#include <unistd.h>

class MountainCompilerException : public exception {
protected:
    string errorMsg = "ERROR: ";
public:
    virtual ~MountainCompilerException() throw() {}
    virtual const char* what() const throw() {
        return errorMsg.c_str();
    }
};

class InvalidTypeException : public MountainCompilerException {
public:
    InvalidTypeException(const string& id, const string & type) {
        errorMsg += id + " isn't a valid " + type + ".";
    }
};

class InvalidNumParameters : public MountainCompilerException {
public:
    InvalidNumParameters(const string& fun, const unsigned int& expected,
        const unsigned int& current) {
            errorMsg += "Function " + fun + " expected " + to_string(expected) +
                " parameters and it has " + to_string(current) + ".";
        }
};

class VariableNotDeclaredException : public MountainCompilerException {
public:
    VariableNotDeclaredException(const string& varName, const string& expectedType) {
            errorMsg += "Variable " + varName + " is not declared or is not a valid "
                + expectedType + ".";
        }
};

// Interpretation structures

typedef pair<int, char> MountainPart;
typedef vector<MountainPart> MountainStruct;

typedef map<string, int> NumericEnvironment;
typedef map<string, MountainStruct> DataEnvironment;

typedef vector<char> PrintableCol;
typedef vector<PrintableCol> PrintableMatrix;

DataEnvironment DE;
DataEnvironment::iterator DEit;

NumericEnvironment NE;
NumericEnvironment::iterator NEit;


//global structures
AST *root;

// function to fill token information
void zzcr_attr(Attrib *attr, int type, char *text) {
    if (type == ID) {
        attr->kind = "id";
        attr->text = text;
    }
    else if (type == NUM) {
        attr->kind = "intconst";
        attr->text = text;
    }
    else {
        attr->kind = text;
        attr->text = "";
    }
}

// function to create a new AST node
AST* createASTnode(Attrib* attr, int type, char* text) {
    AST* as = new AST;
    as->kind = attr->kind;
    as->text = attr->text;
    as->right = NULL;
    as->down = NULL;
    return as;
}

/// create a new "list" AST node with one element
AST* createASTlist(AST *child) {
    AST *as = new AST;
    as->kind = "list";
    as->right = NULL;
    as->down = child;
    return as;
}

/// get nth child of a tree. Count starts at 0.
/// if no such child, returns NULL
AST* child(AST *a, int n) {
    AST *c = a->down;
    for (int i=0; c!=NULL and i<n; i++) c = c->right;
    return c;
}


/// print AST, recursively, with indentation
void ASTPrintIndent(AST *a, string s) {
    if (a == NULL) return;

    cout << a->kind;
    if (a->text != "") cout << "(" << a->text << ")";
    cout << endl;

    AST *i = a->down;
    while (i != NULL and i->right != NULL) {
        cout << s+"  \\__";
        ASTPrintIndent(i, s+"  |"+string(i->kind.size()+i->text.size(), ' '));
        i = i->right;
    }

    if (i != NULL) {
        cout << s+"  \\__";
        ASTPrintIndent(i, s+"   "+string(i->kind.size()+i->text.size(), ' '));
        i = i->right;
    }
}

/// print AST
void ASTPrint(AST *a) {
    while (a != NULL) {
        cout << " ";
        ASTPrintIndent(a, "");
        a = a->right;
    }
}

pair<int, int> evalHeightExpr(const MountainStruct& M) {
    int maxH = 0, minH = 0, currentHeight = 0;
    for (unsigned int i = 0; i < M.size(); ++i) {
        if (M[i].second == '/')
            currentHeight += M[i].first;
        else if (M[i].second == '\\')
            currentHeight -= M[i].first;

        maxH = max(currentHeight, maxH);
        minH = min(currentHeight, minH);
    }
    return {maxH - minH, maxH};
}

bool evalMatchExpr(AST* a) {
    unsigned int expectedCount = 2;
    unsigned int childCount = 0;

    while (child(a, childCount) != NULL) ++childCount;
    if (childCount != expectedCount)
        throw InvalidNumParameters(a->kind, expectedCount, childCount);

    for (unsigned int i = 0; i < expectedCount; ++i)
        if (child(a, i)->kind != "id")
            throw InvalidTypeException(child(a, i)->text, "ID");

    AST* first = child(a, 0);
    DEit = DE.find(first->text);
    if (DEit == DE.end())
        throw VariableNotDeclaredException(first->text, "mountain");
    int firstHeight = evalHeightExpr(DEit->second).first;

    AST* second = child(a, 1);
    DEit = DE.find(second->text);
    if (DEit == DE.end())
        throw VariableNotDeclaredException(first->text, "mountain");
    int secondHeight = evalHeightExpr(DEit->second).first;

    return firstHeight == secondHeight;
}

int evalNumericExpr(AST* a) {
    string k = a->kind;
    if (k == "+" or k == "-" or k == "·" or k == "/") {
        int leftNumber = evalNumericExpr(child(a, 0));
        int rightNumber = evalNumericExpr(child(a, 1));
        if (k == "+") return leftNumber + rightNumber;
        if (k == "-") return leftNumber - rightNumber;
        if (k == "·") return leftNumber * rightNumber;
        if (k == "/") return leftNumber / rightNumber;
    } else if (k == "Height") {
        AST* id = child(a, 0);
        if (id->kind != "id")
            throw InvalidTypeException(id->text, "ID");
        DEit = DE.find(id->text);
        if (DEit != DE.end())
            return evalHeightExpr(DEit->second).first;
        else throw VariableNotDeclaredException(id->text, "mountain");
    } else if (k == "intconst") {
        return stoi(a->text);
    } else if (k == "id") {
        NEit = NE.find(a->text);
        if (NEit != NE.end())
            return NEit->second;
    }
    throw InvalidTypeException(a->text, "mountain or numeric expression");
}

MountainStruct evalAssignShape(AST* a) {
    unsigned int expectedCount = 3;
    unsigned int childCount = 0;

    while (child(a, childCount) != NULL) ++childCount;
    if (childCount != expectedCount)
        throw InvalidNumParameters(a->kind, expectedCount, childCount);

    MountainStruct M(3);
    M[0] = {evalNumericExpr(child(a, 0)), a->kind == "Peak" ? '/' : '\\'};
    M[1] = {evalNumericExpr(child(a, 1)), '-'};
    M[2] = {evalNumericExpr(child(a, 2)), a->kind == "Peak" ? '\\' : '/'};
    return M;
}

MountainStruct evalAssignPart(AST* a) {
    AST* lengthChild = child(a, 0);
    AST* directionChild = child(a, 1);

    if (lengthChild == NULL or directionChild == NULL)
        //TODO: Exception
    if (lengthChild->kind != "intconst")
        throw InvalidTypeException(lengthChild->text, "number");
    string direction = directionChild->kind;
    if (direction != "/" and direction != "-" and direction != "\\")
        throw InvalidTypeException(directionChild->kind, "direction");

    MountainStruct M(1);
    M[0] = {stoi(lengthChild->text), direction[0]};
    return M;
}

MountainStruct evalAssignExpr(AST* a, int ithChild) {
    MountainStruct M;
    while (child(a, ithChild)) {
        AST* childExpr = child(a, ithChild++);
        string kindChild = childExpr->kind;
        if (kindChild == ";") {
            MountainStruct SM = evalAssignExpr(childExpr, 0);
            M.insert(M.end(), SM.begin(), SM.end());
        } else if (kindChild == "Peak" or kindChild == "Valley") {
            MountainStruct SM = evalAssignShape(childExpr);
            M.insert(M.end(), SM.begin(), SM.end());
        } else if (kindChild == "*") {
            MountainStruct SM = evalAssignPart(childExpr);
            M.insert(M.end(), SM.begin(), SM.end());
        } else if (kindChild == "id") {
            DEit = DE.find(childExpr->text);
            if (DEit != DE.end())
                M.insert(M.end(), DEit->second.begin(), DEit->second.end());
            else throw VariableNotDeclaredException(childExpr->text, "mountain");
        } else return M;
    }
    return M;
}

bool evalWellFormed(AST* a) {
    AST *childID = child(a, 0);
    if (childID->kind == "id") {
        DEit = DE.find(childID->text);
        if (DEit != DE.end()) {
            char ultimate = DEit->second[DEit->second.size() - 1].second;
            if (ultimate == '/') return false;
            else if (ultimate == '-') {
                char penultimate = DEit->second[DEit->second.size() - 2].second;
                if (penultimate == '/') return false;
            }
            return true;
        } else throw VariableNotDeclaredException(childID->text, "mountain");
    } else throw InvalidTypeException(childID->text, "ID");
}

bool evalBooleanExpression(AST* a) {
    string k = a->kind;
    if (k == "OR") {
        bool first = evalBooleanExpression(child(a, 0));
        return first or evalBooleanExpression(child(a, 1));
    } else if (k == "AND") {
        bool first = evalBooleanExpression(child(a, 0));
        return first and evalBooleanExpression(child(a, 1));
    } else if (k == "NOT") {
        return not evalBooleanExpression(child(a, 0));
    } else if (k == "==" or k == ">=" or k == ">" or k == "<=" or k == "<") {
        int first = evalNumericExpr(child(a, 0));
        int second = evalNumericExpr(child(a, 1));
        if (k == ">=") return first >= second;
        if (k == ">") return first > second;
        if (k == "<=") return first <= second;
        if (k == "<") return first < second;
        return first == second;
    } else if (k == "Match") {
        return evalMatchExpr(a);
    } else if (k == "Wellformed") {
        return evalWellFormed(a);
    } else throw InvalidTypeException(a->text, "Boolean");
}

void evalCompleteMountain(AST* a) {
    AST *childID = child(a, 0);
    if (childID->kind == "id") {
        DEit = DE.find(childID->text);
        if (DEit != DE.end()) {
            char ultimate = DEit->second[DEit->second.size() - 1].second;
            if (ultimate == '/') {
                DEit->second.push_back({1, '-'});
                DEit->second.push_back({1, '\\'});
            } else if (ultimate == '-') {
                char penultimate = DEit->second[DEit->second.size() - 2].second;
                if (penultimate == '/')
                    DEit->second.push_back({1, '\\'});
            }
        } else throw VariableNotDeclaredException(childID->text, "mountain");
    } else throw InvalidTypeException(childID->text, "ID");
}

void drawMountain(const MountainStruct& M) {
    pair<int, int> p = evalHeightExpr(M);
    int mountainHeight = p.first;
    int currentHeight = p.second;

    string shape = "";
    for (unsigned int i = 0; i < M.size(); ++i) {
        shape += string(M[i].first, M[i].second);
    }

    PrintableMatrix P(shape.size(), PrintableCol(mountainHeight + 1, ' '));

    for (unsigned int i = 0; i < shape.size(); ++i) {
        P[i][currentHeight] = shape[i];
        for (unsigned int j = currentHeight + 1; j < P[i].size(); ++j)
            P[i][j] = '#';

        if (shape[i] == '/' or (shape[i+1] == '/' and shape[i] == '-'))
            --currentHeight;
        else if (i+1 < shape.size() and
            (shape[i+1] == '\\' or (shape[i+1] == '-' and shape[i] == '\\')))
            ++currentHeight;
    }

    for (unsigned int j = 0; j < P[0].size(); ++j) {
        for (unsigned int i = 0; i < P.size(); ++i)
            cout << P[i][j];
        cout << endl;
    }
}

void evalDrawMountain(AST* a) {
    AST *childID = child(a, 0);
    if (childID->kind == "id") {
        DEit = DE.find(childID->text);
        if (DEit != DE.end())
            drawMountain(DEit->second);
        else throw VariableNotDeclaredException(childID->text, "mountain");
    } else {
        MountainStruct M = evalAssignExpr(a, 0);
        drawMountain(M);
    }
}

void executeMountains(AST* a) {
    int ithChild = 0;
    while(child(a, ithChild)) {
        AST* ithExpr = child(a, ithChild);
        string kindChild = ithExpr->kind;
        try {
            if (kindChild == "is") {
                AST* exprId = child(ithExpr, 0);
                if (exprId->kind != "id")
                    throw InvalidTypeException(exprId->text, "ID");

                MountainStruct M = evalAssignExpr(ithExpr, 1);
                if (M.size()) {
                    DEit = DE.find(exprId->text);
                    if (DEit == DE.end()) DE.insert({exprId->text, M});
                    else DEit->second = M;

                    NEit = NE.find(exprId->text);
                    if (NEit != NE.end())
                        NE.erase(NEit);
                } else {
                    int numericValue = evalNumericExpr(child(ithExpr, 1));
                    NEit = NE.find(exprId->text);
                    if (NEit == NE.end()) NE.insert({exprId->text, numericValue});
                    else NEit->second = numericValue;

                    DEit = DE.find(exprId->text);
                    if (DEit != DE.end())
                        DE.erase(DEit);
                }
            } else if (kindChild == "Complete") {
                evalCompleteMountain(ithExpr);
            } else if (kindChild == "Draw") {
                evalDrawMountain(ithExpr);
            } else if (kindChild == "if") {
                if (evalBooleanExpression(child(ithExpr, 0)))
                    executeMountains(child(ithExpr, 1));
            } else if (kindChild == "while") {
                while (evalBooleanExpression(child(ithExpr, 0)))
                    executeMountains(child(ithExpr, 1));
            } else throw InvalidTypeException(kindChild, "instruction");
        } catch(exception &e) {
            cerr << e.what() << endl;
            exit(1);
        }
        ++ithChild;
    }
}

void printFinalHeights() {
    cout << endl << "----------------------------------------" << endl;
    for (DEit = DE.begin(); DEit != DE.end(); ++DEit) {
        int height = evalHeightExpr(DEit->second).first;
        cout << endl << "l'altitut final de " << DEit->first << " és: " << height << endl;
        drawMountain(DEit->second);
    }
}

int main(int argc, char** argv) {
    root = NULL;
    ANTLR(program(&root), stdin);
    if (argc == 2 and argv[1] == "-t")
        ASTPrint(root);
    executeMountains(root);
    printFinalHeights();
}
>>


#lexclass START
// Keywords
#token AND "AND"
#token OR "OR"
#token NOT "NOT"
#token IF "if"
#token ENDIF "endif"
#token WHILE "while"
#token ENDWHILE "endwhile"
#token CONCAT ";"
#token COMPARE "\< | \<= | \>= | \> | =="
// Definitions
#token NUM "[0-9]+"
#token TIMES "\*"
#token DIRECTION "\/ | \- | \\"
// Functions
#token SHAPE "Peak | Valley"
#token MATCH "Match"
#token HEIGHT "Height"
#token WELLFORMED "Wellformed"
#token COMPLETE "Complete"
#token DRAW "Draw"
// Operators
#token ASSIGN "is"
#token ID "[A-Za-z][A-Za-z0-9_]*"
#token PLUS "\+"
#token MINUS "\$"
#token MULT "\·"
#token DIV  "\/"
// WhiteSpaces
#token SPACE "[\ \t\n\s]" << zzskip(); >>

program: (instruction)* << #0 = createASTlist(_sibling); >>;
instruction: assign | condition | loop | draw | complete;

assign: ID ASSIGN^ (mountain);
condition: IF^ "\("! boolexprP0 "\)"! program ENDIF!;
loop: WHILE^ "\("! boolexprP0 "\)"! program ENDWHILE!;
draw: DRAW^ "\("! mountain "\)"!;
complete: COMPLETE^ "\("! ID "\)"!;

mountain: part (CONCAT^ part)*;
part: shape | section | idref;

shape: SHAPE^ "\("! operationP0 ","! operationP0 ","! operationP0 "\)"!;
section: operationP0 (TIMES^ DIRECTION |);
idref: "#"! ID;

operationP0: operationP1 ((PLUS^ | MINUS^) operationP1)*;
operationP1: numericexpr ((MULT^ | DIV^) numericexpr)*;

height: HEIGHT^ "\("! idref "\)"!;
match: MATCH^ "\("! idref ","! idref "\)"!;
wellformed: WELLFORMED^ "\("! ID "\)"!;
comparation: operationP0 COMPARE^ operationP0;

boolexprP0: boolexprP1 (OR^ boolexprP1)*;
boolexprP1: boolexprP2 (AND^ boolexprP2)*;
boolexprP2: (NOT^ |) boolexprP3;
boolexprP3: match | wellformed | comparation;

numericexpr: NUM | height | ID;
