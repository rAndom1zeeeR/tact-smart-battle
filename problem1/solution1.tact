//
// Contract for voting "yes" or "no" on a proposal
//

message Vote {
    value: Bool;
}

struct ProposalState {
    yesCount: Int as uint32;
    noCount: Int as uint32;
}

struct Init {
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;
}

contract Proposal {
    // State variables
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;
    yesCount: Int as uint32;
    noCount: Int as uint32;
    voters: map<Address, Bool>; // Map of voter addresses to their votes (true = "yes", false = "no")
    totalVotes: Int as uint32;
    
    // Contract initialization
    init(data: Init) {
        self.proposalId = data.proposalId;
        self.votingEndingAt = data.votingEndingAt;
        self.yesCount = 0;
        self.noCount = 0;
        self.voters = emptyMap();
        self.totalVotes = 0;
    }

    // Empty handler for deployment
    receive() { }

    // Message handler for voting
    receive(msg: Vote) {
        // Check if voting is still open
        let now = now();
        if (now >= self.votingEndingAt) {
            throw(100); // Voting has ended
        }
        
        // Check if vote limit has been reached
        if (self.totalVotes >= 100) {
            throw(101); // Maximum votes reached
        }
        
        // Check if voter has already voted
        let sender = sender();
        // Check for key presence in the map using get and null check
        if (self.voters.get(sender) != null) {
            throw(102); // Voter has already voted
        }
        
        // Record the vote
        self.voters.set(sender, msg.value);
        self.totalVotes += 1;
        
        if (msg.value) {
            self.yesCount += 1;
        } else {
            self.noCount += 1;
        }
        
        // Reimburse excess funds
        let excess = myBalance() - 10000000; // 0.01 TON for gas
        if (excess > 0) {
            send(SendParameters{
                to: sender,
                value: excess,
                bounce: false,
                body: emptyCell()
            });
        }
    }

    // Getter for retrieving voting results
    get fun proposalState(): ProposalState {
        return ProposalState{
            yesCount: self.yesCount,
            noCount: self.noCount
        };
    }
}
