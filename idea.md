Okay so imo the most optimal approach out of all presented has been one in lab4.
It splits responsbility between multiple, potentially independent MECs, it's
alright at anonymizing voter's identity, voters can verify their vote. Still, it
had a few issues:

- *Even a single* MEC can deanonymize anyone
- If all MECs cooperate they can effectively decrypt candidate's ID (although
  this isn't really impactful all things considered)
- Only verifiable thing is voter count, so with total cooperation votes can be
  made up for people who haven't voted

So, I'm aiming at the following ideas/improvements:

- Independently from the ballots, gather and publish whether the person has
  voted at all. This has to be signed, so it can't be faked. Potentially a
  public voter list allows to verify whether each voter is an actual existing
  human being, but it's a bad idea to publish too much personal data
- Have many commissions, each person randomly decides which ones to send it to.
  Voter is incentivised to choose randomly, which strengthens the protocol
- Make ballot ID combined from the multiplier thingy, so that a single MEC can't
  identify a voter from the final published list, even if it cooperates with EC.

***

I thought the whole night about it, and actually the multiplier thingy seems
redundant. The last lab is really inefficient the way it is set up, but if
instead we make a loop out of MECs it anonymizes all the votes, and allows for
verifying exactly which MEC violated the rules.

What I'm currently thinking: we have EC. A voter publicly asks EC to sign an
index of MEC they want to start with, EC does so and marks voter as having
voted. Voter encrypts their ballot with EC's public key, and then any amount of
layers they want, in reverse order of MECs. To each layer they prepend an ID.
They then send the pile to the MEC they have chosen, MEC marks that person as
having submitted. At each step, MEC decrypts the pile, publishes attached ID,
and passes the pile to the next MEC. If decryption fails, they send the pile to
EC, as supposedly that's the final layer (alternatively, they make that pile
public, im not sure what benefits it has). Voter, having remembered all of their
IDs (and maybe having sent a signed hash of them prior), can pinpoint exactly
where their ballot has been lost.

EC controls whether a person has voted. It probably publishes each request to
vote, so that we have a max amount of ballots (i.e, MEC can't just make shit
up). EC can vote in place of non-existent voters, but it can't vote for
abstained voters, as it can't fabricate the request to vote. EC can't deny the
right to vote, unless it has a signed request, and if it has a signed request it
must have approved the request, or if it hasn't, the chosen MEC will be able to
testify. A vote can't be unanonymized, unless every single MEC *and* EC
cooperate. 

***

## Acquiring the right to vote

1. Voter picks a ballot (candidate, uid), a list of salts, entry MEC, forms a
   pile
2. Voter sends to EC entry MEC, hash of the pile, hash of the salts, signs the
   message
3. EC publishes the request, responds with a signed approval message
4. Voter sends to entry MEC the pile, signed approval message, signs the message
5. MEC sends to EC confirmation that it has received the approval, EC publishes
   that (associated with its respective #3)
   
   - Unless EC and entry MEC cooperate, vote cannot be denied

## The carousel

1. MEC publishes hashes of received piles
    - If missing, voter can recreate the file, and prove that the previous MEC
      did receive the pile, and it was not undecryptable
    - If missing in the very first MEC, voter can use the hash sent to EC
2. MEC decrypts each pile using its private key
3. MEC publishes all piles that failed to decrypt
4. MEC publishes all salts of piles that were decrypted successfully
    - Similar to #1
5. MEC sends the pile to the next MEC

## Ending

1. EC collects all published "undecryptable" piles
2. EC decrypts, all of them, eliminates duplicates
3. EC publishes all ballots

That's roooooughly it, im still not sure about some details, but we will see
