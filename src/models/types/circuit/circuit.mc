-- Represents a electrical circuit. A circuit consists of a Series connection, a Parallel connection,
-- or a component. A series or parallel connection then consists of a list of circuits.
-- All components in a series or parallel connection are considered to be connected
-- according to the order of the list, 
-- and all parallel/series connections are connected by the first component/components
-- (by order of the list).
-- All components have a type, a name and a value (voltage/resistance/None ()).

include "char.mc"

type Circuit
    con Component : (circ_type,name,value,isConnected) -> Circuit
    con Series : [Component] -> Circuit 
    con Parallel : [Component] -> Circuit

-- returns all components in circuit circ
recursive
let circGetAllComponents = lam circ.
    let formatComponents = lam list. foldl (lam lst. lam comp. concat lst (circGetAllComponents comp)) [] list in
    match circ with Component (_,name,_,_) then [circ] 
    else match circ with Series circ_lst then 
        formatComponents circ_lst
    else match circ with Parallel circ_lst then 
        formatComponents circ_lst
    else []
end

-- creates edges between all elements in from_lst to all elements in to_lst
-- returns a list of tuples (a,b)
let makeEdges = lam from_lst. lam to_lst.
    foldl (lam lst. lam a. 
        concat lst (map (lam b. 
            match a with Component (_,a_name,_,_) then
                match b with Component (_,b_name,_,_) then
                    (a,b)
                else error "edges must be between components"
            else error "edges must be between components"
            ) 
        to_lst)
    ) [] from_lst
    
utest makeEdges [Component ("ground","g",None (), false),Component("capacitator","c",Some (8.0),true)]
                [Component ("ground","g",None (), false),Component ("resistor","R3",Some (1.4),true)] 
                with 
                [
                    (Component ("ground","g",None (), false),Component ("ground","g",None (), false)),
                    (Component ("ground","g",None (), false),Component ("resistor","R3",Some (1.4),true)),
                    (Component("capacitator","c",Some (8.0),true),Component ("ground","g",None (), false)),
                    (Component("capacitator","c",Some (8.0),true),Component ("resistor","R3",Some (1.4),true))
                ] 
-- gets the first component (or components in case of a parallel connection) in the circuit
recursive
let circHead = lam circ. 
    match circ with Component (_,name,_,_) then [circ]
    else match circ with Series lst then circHead (head lst)
    else match circ with Parallel lst then 
        foldl (lam res. lam elem. concat res (circHead elem)) [] lst
    else []
end

utest circHead (Series [Component ("ground","g",None (), false),Component ("resistor","R3",Some (1.4),true), Component("capacitator","c",Some (8.0),true)])
    with [Component ("ground","g",None (), false)]
-- gets the last component (or components in case of a parallel connection) in the circuit
recursive
let circLast = lam circ.
   match circ with Component (_,name,_,_) then [circ] 
    else match circ with Series lst then circLast (last lst)
    else match circ with Parallel lst then 
        foldl (lam res. lam elem. concat res (circLast elem)) [] lst
    else []
end

utest circLast (Series [Component ("ground","g",None (), false),Component ("resistor","R3",Some (1.4),true), Component("capacitator","c",Some (8.0),true)])
    with [Component("capacitator","c",Some (8.0),true)]

-- returns all connections in the circuit as a list of tuples 
-- where (a,b) means that there is a wire from a to b
recursive
let circGetAllEdges = lam circ.
    match circ with Component (_,name,_,_) then []
    else match circ with Series circ_lst then
        if (eqi (length circ_lst) 0) then []
        else
            join (zipWith (lam a. lam b.
                let from = circLast a in
                let maybe_to = circHead b in
                let to = maybe_to in
                let a_edges = circGetAllEdges a in
                concat (a_edges) (makeEdges from to)
            )(init circ_lst) (tail circ_lst))
    else match circ with Parallel circ_lst then
        if (eqi (length circ_lst) 0) then []
        else
            let final_index = subi (length (circ_lst)) 1 in
            join (mapi (lam i. lam comp. 
                let from = circLast comp in 
                let other_components = slice circ_lst (addi 1 i) final_index in
                let to = join (map (lam x. 
                    circHead x
                ) other_components) in
                let from_edges = circGetAllEdges comp in
                let edges = concat (from_edges) (makeEdges from to) in
                if (eqi i 0) then 
                    let from_snd = join (map (lam x. 
                    circLast x
                ) other_components) in
                let to_snd = from in
                join [edges,makeEdges from_snd to_snd] 
                else edges
            ) circ_lst)
    else []
end

-- calculates the number of supporting nodes of a parallel connection
recursive
let countInnerDepth = lam circ.
    let calcDepth = lam c_list. max (lam l. lam r. subi l r) (map (lam c. countInnerDepth c) c_list) in
    match circ with Series circ_lst then
        calcDepth circ_lst
    else match circ with Parallel circ_lst then
        addi (length circ_lst) (calcDepth circ_lst)
    else 0
end

utest countInnerDepth (Parallel [Component ("battery","V1",Some (11.0),true),
            Component ("resistor","R3",Some (1.4),true)]) with 2
mexpr
let circ = Parallel [
            Series [
            Component ("battery","V1",Some (11.0),true),
            Component ("resistor","R3",Some (1.4),true)
            ],
            Series [
                Component ("ground","g",None (), false),
                Component("capacitator","c",Some (8.0),true)
            ]
        ] in
utest (length (circGetAllComponents circ)) with 4 in
utest (length (circGetAllEdges circ)) with 4 in ()