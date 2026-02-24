%{
open Types
%}

(* %token [<type>] ID *)
%token <string> LABEL
%token <int> NUMBER
%token COMMA
%token SEMI
%token LANGB
%token RANGB
%token LPAREN
%token RBRACKET
%token LBRACKET
%token RPAREN
%token INACTIVE
%token OUTPUT
%token INPUT
%token PREFIX
%token EXTERNAL_CHOICE
%token INTERNAL_CHOICE
%token PAR
%token STAR
%token HASH
%token DEFINITION
%token EOF

%left INTERNAL_CHOICE
%left EXTERNAL_CHOICE
%left PAR
%left PREFIX

%start <(string * chan list * Lambda.t) list * Lambda.t> prog

%%

prog:
    | p = proc_defs; e = expr; EOF { (p, e) }
    | e = expr; EOF { ([], e) }

(*
proc_def:
    | p = proc_defs { p }
    | { [] }
*)

(*
proc_defs:
    | s = LABEL; LBRACKET; p = param; RBRACKET; DEFINITION; e = expr { [(s,p,e)] }
    | pr = proc_defs; s = LABEL; LBRACKET; p = param; RBRACKET; DEFINITION; e = expr { (s,p,e)::pr }
*)

proc_defs:
    | s = LABEL; LBRACKET; p = param; RBRACKET; DEFINITION; e = expr; SEMI; pr = proc_defs { (s,p,e)::pr }
    | { [] }

param:
    | e = params { e }
    | { [] }

params:
    | id = LABEL { [(id, default_ch_attr)] }
    | p = params; COMMA; id = LABEL { (id, default_ch_attr)::p }

expr:
    | EOF { LNil }
    | INACTIVE { LNil }
    | s = LABEL; OUTPUT; PREFIX; e = expr { LList(EEta(AOut(s, default_ch_attr)), e) }
    | s = LABEL; INPUT; PREFIX; e = expr { LList(EEta(AIn(s, default_ch_attr)), e) }
    | HASH; s = LABEL; PREFIX; e = expr { LList(EEta(AClose(s, default_ch_attr)), e) }
    | s = LABEL; LBRACKET; p = param; RBRACKET; PREFIX; e = expr { LList(EEta(ACall(s, p)), e) }
    | LPAREN; e = expr; RPAREN { e }
    | e1 = expr; INTERNAL_CHOICE; e2 = expr { LOrI(e1, e2) }
    | e1 = expr; EXTERNAL_CHOICE; e2 = expr { LOrE(e1, e2) }
    | e1 = expr; PAR; e2 = expr { LPar(e1, e2) }
    | STAR; s = LABEL; INPUT; PREFIX; e = expr { LRepl(EEta(AIn(s, default_ch_attr)), e) }
