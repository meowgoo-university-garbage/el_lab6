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
