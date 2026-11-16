package main

import "core:fmt"
import "core:slice"
import "core:math/rand"

import "core:math/big"

import "./rsa"
import "core:crypto/hash"


MINOR_EC_COUNT :: 3

Country :: enum {
    Ukraine,
    Russia,
    Poland,
}

Person :: struct {
    id : u64,
    fullname : string,
    country : Country,
    age : int,

    rememberedSalts : [dynamic]u64,
    rememberedEntryMecId : u64,
    rememberedSteps : u64,
    rememberedId : u64,
    rememberedAlreadyFound : bool,
    rememberedViolation : bool,

    key_prv : rsa.Key_Private,
    key_pub : rsa.Key_Public,
}

Candidate :: struct {
    id : u64,
    fullname : string,

    votes : int,
}


is_just :: proc (v : Maybe($ty)) -> bool {
    _, ok := v.?
    return ok
}

is_none :: proc (v : Maybe($ty)) -> bool {
    _, ok := v.?
    return !ok
}


Begin_AcquireVoteRequest :: struct {
    person_id : u64,
    mec_id    : u64,
    hash_pile : []u8,
    hash_salt : []u8,

    signature : []u8,
}

Begin_VoteApproval :: struct {
    person_id : u64,
    mec_id    : u64,

    signature : []u8,
}

Begin_SendVoteRequest :: struct {
    approval  : Begin_VoteApproval,
    pile      : []u8,
}

Begin_VoteConfirmation :: struct {
    person_id : u64,
    mec_id    : u64,

    signature : []u8,
}




Voter :: struct {
    person_id : u64,
    fullname : string,
    key_pub : rsa.Key_Public,

    request : Maybe(Begin_AcquireVoteRequest),
    confirm : Maybe(Begin_VoteConfirmation),
}

VoterSingle :: struct {
    person_id : u64,
    fullname : string,
    key_pub : rsa.Key_Public,

    alreadyVoted : bool,
}

ElectionCommission :: struct {
    key_prv : rsa.Key_Private,
    key_pub : rsa.Key_Public,

    candidates : []Candidate,
    voters : [dynamic]Voter,
}

MinorElectionCommission :: struct {
    id : u64,
    key_prv : rsa.Key_Private,
    key_pub : rsa.Key_Public,

    voters : [dynamic]VoterSingle,

    pileQueue : [dynamic][]u8,
    piles     : [dynamic][]u8,

    published_final     : [dynamic][]u8,
    published_salt      : [dynamic]u64,
    published_hash_pre  : [dynamic][]u8,
    published_hash_post : [dynamic][]u8,
}




Ballot :: struct {
    candidate_id : u64,
    id : u64,
}





u8arr_from_u64 :: proc (s : u64) -> (r : [8]u8) {
    s := s
    ss := slice.bytes_from_ptr(&s, size_of(u64))
    for &rr, i in r { rr = ss[i] }
    return
}

main :: proc () {
    people : []Person = {
        Person{ id = 0, fullname = "Vitalya Gryb", country = .Ukraine, age = 23 },
        Person{ id = 1, fullname = "Svitlana Zhizha", country = .Ukraine, age = 27 },
        Person{ id = 2, fullname = "Zheka Zrada", country = .Ukraine, age = 19 },
        Person{ id = 3, fullname = "Grzegorz Brzeczyszczykiewicz", country = .Ukraine, age = 153 },
        Person{ id = 5, fullname = "Yaroslav Aboba", country = .Ukraine, age = 34 },
    }



    for &p in people {
        p.key_prv, p.key_pub = rsa.keygen()
        fmt.printfln("Generated private key for %v", p.fullname)
    }
    fmt.println()



    ec : ElectionCommission = {
        candidates = {
            Candidate{ id = 67, fullname = "Petro Poroshenko", votes = 0 },
            Candidate{ id = 69, fullname = "Amogus", votes = 0 },
        },
    }

    ec.key_prv, ec.key_pub = rsa.keygen()
    fmt.printfln("Generated private key for ELECTION COMMISSION")
    
    EC_PUBLIC_KEY := ec.key_pub
    fmt.println()

    fmt.println("List of candidates")
    for c in ec.candidates {
        fmt.printfln("%v | ID: %v", c.fullname, c.id)
    }
    fmt.println()

    mecs : [MINOR_EC_COUNT]MinorElectionCommission
    for &mec, i in mecs {
        mec.id = cast(u64)i
        mec.key_prv, mec.key_pub = rsa.keygen()
        fmt.printfln("Generated private key for MINOR ELECTION COMMISSION #%v", i)
    }
    fmt.println()



    for &p in people {
        fmt.printfln("Registering voter %v", p.fullname)

        append(&ec.voters, Voter{
            person_id = p.id,
            fullname = p.fullname,
            key_pub = p.key_pub,
        })

        fmt.printfln("VOTED REGISTERED")
    }
    fmt.println()

    fmt.printfln("Sending voter lists from EC to all MECs")
    for &mec in mecs {
        for &v in ec.voters {
            append(&mec.voters, VoterSingle{
                person_id = v.person_id,
                fullname = v.fullname,
                key_pub = v.key_pub,

                alreadyVoted = false,
            })
        }
    }
    fmt.println()



    findVoter :: proc (id : u64, voters : [dynamic]Voter) -> (vi : u64, vf : bool) {
        id := id
        context.user_ptr = &id
        vii : int
        vii, vf = slice.linear_search_proc(voters[:], proc (v : Voter) -> bool {
            return (v.person_id == (cast(^u64)context.user_ptr)^)
        })
        vi = cast(u64)vii

        return
    }

    findCandidate :: proc (id : u64, cs : []Candidate) -> (ci : u64, cf : bool) {
        id := id
        context.user_ptr = &id
        cii : int
        cii, cf = slice.linear_search_proc(cs, proc (c : Candidate) -> bool {
            return (c.id == (cast(^u64)context.user_ptr)^)
        })
        ci = cast(u64)cii

        return
    }

    fmt.printfln("VOTING STARTED")
    for &p in people {
        candidate := rand.choice(ec.candidates)
        fmt.printfln("Voter %v chooses candidate %v", p.fullname, candidate.fullname)
        id := rand.uint64()

        ballot := Ballot{ candidate_id = candidate.id, id = id }
        final, result_encrypt := rsa.encrypt_value(&EC_PUBLIC_KEY, ballot)
        if !result_encrypt {
            fmt.printfln("FATAL: encryption failed")
        }

        bytes := final

        entryMec := rand.choice(mecs[:]).id
        steps := cast(u64)rand.int_range(len(mecs) + 2, 5 * len(mecs))
        p.rememberedEntryMecId = entryMec
        p.rememberedSteps = steps

        startMec := (entryMec + steps - 1) % len(mecs)
        currentMec := startMec

        for i := steps; i > 0; i -= 1 {
            steps -= 1

            salt := rand.uint64()
            salt = rand.uint64_range(0, 100000)

            inject_at(&p.rememberedSalts, 0, salt)

            layer : [dynamic]u8
            defer delete(layer)

            saltb := u8arr_from_u64(salt)
            append(&layer, ..saltb[:])
            append(&layer, ..bytes)

            delete(bytes)

            bytes, result_encrypt = rsa.encrypt_long(&mecs[currentMec].key_pub, layer[:])
            if currentMec == 0 { currentMec = len(mecs) }
            currentMec -= 1

            if rand.float32() < 0.05 {
                fmt.printfln("VIOLATION: I AM STUUUUUPID")
                replacement : []u8 = { 0xab, 0xcd, 0xef, 0x01, 0x23, 0x45, 0x67, 0x67 }
                bytes = slice.clone(replacement)
            }
        }

        fmt.printfln("\tID: %v", id)
        fmt.printfln("\tSalts: %v", p.rememberedSalts)
        fmt.printfln("\tEntry MEC: %v", p.rememberedEntryMecId)


        request := Begin_AcquireVoteRequest{
            person_id = p.id,
            mec_id = entryMec,
            hash_pile = hash.hash_bytes(.SHA256, bytes),
            hash_salt = {},

            signature = {},
        }

        {
            sigBytes : [dynamic]u8
            defer delete(sigBytes)
            pidB := u8arr_from_u64(request.person_id)
            append(&sigBytes, ..pidB[:])
            midB := u8arr_from_u64(request.mec_id)
            append(&sigBytes, ..midB[:])
            append(&sigBytes, ..request.hash_pile)
            append(&sigBytes, ..request.hash_salt)
            request.signature = rsa.sign(&p.key_prv, sigBytes[:])
        }



        // EC
        receivedRequest := request

        if receivedRequest.mec_id >= len(mecs) {
            fmt.printfln("bad mec")
            continue
        }

        vi, vf := findVoter(receivedRequest.person_id, ec.voters)
        if !vf {
            fmt.printfln("no voter")
            continue
        }

        if is_just(ec.voters[vi].request) {
            fmt.printfln("already voted")
            continue
        }

        {
            sigBytes : [dynamic]u8
            defer delete(sigBytes)
            pidB := u8arr_from_u64(receivedRequest.person_id)
            append(&sigBytes, ..pidB[:])
            midB := u8arr_from_u64(receivedRequest.mec_id)
            append(&sigBytes, ..midB[:])
            append(&sigBytes, ..receivedRequest.hash_pile)
            append(&sigBytes, ..receivedRequest.hash_salt)

            if !rsa.verify(&ec.voters[vi].key_pub, sigBytes[:], receivedRequest.signature) {
                fmt.printfln("bad sign")
                continue
            }

            fmt.printfln("signature verified")
        }

        ec.voters[vi].request = receivedRequest

        approval := Begin_VoteApproval{
            person_id = receivedRequest.person_id,
            mec_id    = receivedRequest.mec_id,
        }

        {
            sigBytes : [dynamic]u8
            defer delete(sigBytes)
            pidB := u8arr_from_u64(approval.person_id)
            append(&sigBytes, ..pidB[:])
            midB := u8arr_from_u64(approval.mec_id)
            append(&sigBytes, ..midB[:])

            approval.signature = rsa.sign(&ec.key_prv, sigBytes[:])
        }

        // VOTER
        receivedApproval := approval



        voteRequest := Begin_SendVoteRequest{
            approval  = receivedApproval,
            pile      = bytes,
        }


        // MEC
        receivedVoteRequest := voteRequest
        mecId := receivedVoteRequest.approval.mec_id

        if is_just(ec.voters[vi].confirm) {
            fmt.printfln("already voted")
            continue
        }

        if is_none(ec.voters[vi].request) {
            fmt.printfln("not requested yet")
            continue
        }

        {
            sigBytes : [dynamic]u8
            defer delete(sigBytes)
            pidB := u8arr_from_u64(receivedVoteRequest.approval.person_id)
            append(&sigBytes, ..pidB[:])
            midB := u8arr_from_u64(receivedVoteRequest.approval.mec_id)
            append(&sigBytes, ..midB[:])

            if !rsa.verify(&EC_PUBLIC_KEY, sigBytes[:], receivedVoteRequest.approval.signature) {
                fmt.printfln("bad ec signature")
                continue
            }
        }

        {
            pileHash := hash.hash_bytes(.SHA256, receivedVoteRequest.pile)
            defer delete(pileHash)

            if !slice.equal(pileHash, ec.voters[vi].request.?.hash_pile) {
                fmt.printfln("weird request")
                continue
            }
        }


        confirmation := Begin_VoteConfirmation{
            person_id = receivedVoteRequest.approval.person_id,
            mec_id    = receivedVoteRequest.approval.mec_id,
        }

        {
            sigBytes : [dynamic]u8
            defer delete(sigBytes)
            pidB := u8arr_from_u64(confirmation.person_id)
            append(&sigBytes, ..pidB[:])
            midB := u8arr_from_u64(confirmation.mec_id)
            append(&sigBytes, ..midB[:])

            confirmation.signature = rsa.sign(&mecs[mecId].key_prv, sigBytes[:])
        }

        ec.voters[vi].confirm = confirmation

        append(&mecs[mecId].pileQueue, receivedVoteRequest.pile)
    }
    fmt.println()

    fmt.printfln("PROCESSING VOTES")

    finalBallots : [dynamic]Ballot
    for day in 0 ..< 9999999 {
        fmt.printfln("============DAY %v", day)
        isThereWorkToDo := false

        for &mec in mecs {
            clear(&mec.piles)
            for p in mec.pileQueue {
                append(&mec.piles, p)
                isThereWorkToDo = true
            }
            clear(&mec.pileQueue)

            clear(&mec.published_salt)
            clear(&mec.published_final)
            clear(&mec.published_hash_pre)
            clear(&mec.published_hash_post)
        }

        if !isThereWorkToDo { break }

        for &mec in mecs {
            fmt.printfln("MEC #%v", mec.id)
            nextMecIndex := mec.id + 1
            if nextMecIndex == len(mecs) { nextMecIndex = 0 }
            nextMec := &mecs[nextMecIndex]

            for p in mec.piles {
                append(&mec.published_hash_pre, hash.hash_bytes(.SHA256, p))

                uncovered, result_decrypt := rsa.decrypt_long(&mec.key_prv, p)
                if !result_decrypt || len(uncovered) < 8 { 
                    fmt.printfln("\tDecryption failed, possibly finalized ballot")
                    delete(uncovered)
                    append(&mec.published_final, p)
                    continue
                }

                // NOTE: for some bizarre reason this segfaults????
                // delete(p)

                salt := (cast(^u64)raw_data(uncovered))^
                uncovered = uncovered[size_of(u64):]

                append(&mec.published_salt, salt)
                append(&mec.published_hash_post, hash.hash_bytes(.SHA256, uncovered))

                if rand.float32() < 0.01 {
                    fmt.printfln("VIOLATION: !!!!! I AM EVILLLL")
                }
                else {
                    append(&nextMec.pileQueue, uncovered)
                }
            }

            rand.shuffle(mec.published_salt[:])
            rand.shuffle(mec.published_hash_post[:])

            fmt.printfln("\tPUB Salt: %v", mec.published_salt[:])
        }

        finalPiles : [dynamic][]u8
        defer delete(finalPiles)

        for &mec in mecs {
            for p in mec.published_final {
                append(&finalPiles, p)
            }
        }

        fmt.printfln("EC")
        for p in finalPiles {
            uncovered, result_decrypt := rsa.decrypt_value(&ec.key_prv, p, Ballot)
            if !result_decrypt {
                fmt.printfln("\tokay this wasnt actually a ballot")
                continue
            }

            ci, cf := findCandidate(uncovered.candidate_id, ec.candidates)
            fmt.printfln("\tUncovered ballot %v %v", uncovered, ec.candidates[ci].fullname)

            ec.candidates[ci].votes += 1
            append(&finalBallots, uncovered)
        }



        for &mec in mecs {
            ingoing := len(mec.published_hash_pre)
            outgoing := len(mec.published_hash_post) + len(mec.published_final)
            nextMec := mecs[(mec.id + 1) % len(mecs)]

            if ingoing != outgoing || len(mec.published_hash_post) != len(mec.published_salt) || len(nextMec.pileQueue) != len(mec.published_hash_post) {
                fmt.printfln("SOMETHING FISHY WITH MEC %v", mec.id)
            }
        }


        for &p in people {
            if cast(u64)day >= p.rememberedSteps { continue }

            salt := p.rememberedSalts[day]
            mec := mecs[(p.rememberedEntryMecId + cast(u64)day) % len(mecs)]

            _, found := slice.linear_search(mec.published_salt[:], salt)
            if !found {
                fmt.printfln("%v: DIDNT FIND MY SAAAAAALT", p.fullname)
            }
        }
    }
    fmt.println()

    fmt.printfln("PUBLISHING VOTES")

    for c in ec.candidates {
        fmt.printfln("Candidate %v : %v votes", c.fullname, c.votes)
    }
    fmt.println()

    fmt.printfln("LIST OF BALLOTS")
    for b in finalBallots {
        ci, cf := findCandidate(b.candidate_id, ec.candidates)
        fmt.printfln("Ballot for %v | ID : %v", ec.candidates[ci].fullname, b.id)
    }
}
