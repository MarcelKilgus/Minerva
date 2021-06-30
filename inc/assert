* Improved assert - accepts comparison operators
        nolist

assert macro
 local a,b,i,j,o,v
j setnum 1
l maclab
i setnum [j]
j setnum [i]+1
o setstr =
v setstr .>.<.>=.<=.=.<>.~=.
b setstr .[.parm([j])].
 ifnum [.instr(v,b)] = 0 goto t
o setstr [.parm([j])]
j setnum [j]+1
t maclab
a setstr [.parm([i])]
b setstr [.parm([j])]
 ifnum [a] [o] [b] goto x
v setnum [a]
 ifstr [a] = [v] goto r
a setstr [a](=[v])
r maclab
v setnum [b]
 ifstr [b] = [v] goto s
b setstr [b](=[v])
s maclab
 error we do not have [a] [o] [b]
x maclab
 ifnum [j] < [.nparms] goto l
 endm

        list
