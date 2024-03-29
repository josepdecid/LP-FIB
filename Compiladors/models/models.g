#header
<<
#include <string>
#include <iostream>
#include <exception>
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
#include <vector>
#include <unordered_map>

//global structures
AST *root;

// function to fill token information
void zzcr_attr(Attrib *attr, int type, char *text) {
    attr->kind = text;
    attr->text = "";
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

int main(int argc, char** argv) {
    root = NULL;
    ANTLR(model(&root), stdin);
    ASTPrint(root);
}
>>


#lexclass START
// Keywords
#token START "start"
#token PAR "\+"
#token EXC "#"
#token INC "\|"
#token SEQ ";"
#token LPAR "\("
#token RPAR "\)"
#token END "end"
#token CONNECTION "connection"
#token FILEP "file"
#token FILEDIR "\<\- | \-\>"
#token QUERIES "QUERIES"
#token CRITICAL "critical"
#token DIFFERENCE "difference"
#token CORRECTFILE "correctfile"
#token ID "[a-zA-Z][a-zA-Z0-9]*";
// WhiteSpaces
#token SPACE "[\ \t\n\s]" << zzskip(); >>

model: defs QUERIES! queries << #0 = createASTlist(_sibling); >>;
defs: (role | connection | file)* << #0 = createASTlist(_sibling); >>;

role: START! processP0 END! ID^;
connection: CONNECTION^ ID ID;
file: FILEP^ filep;
filep: FILEDIR^ ID ID;
queries: (critical | difference | correctfile)* << #0 = createASTlist(_sibling); >>;
critical: CRITICAL^ ID;
difference: DIFFERENCE^ ID ID;
correctfile: CORRECTFILE^ ID;

processP0: processP1 (PAR^ processP1)*;
processP1: processP2 (EXC^ processP2)*;
processP2: processP3 (INC^ processP3)*;
processP3: processP4 (SEQ^ processP4)*;
processP4: LPAR! processP0 RPAR! | ID;
