// Scalable Voting Contract for a Single Proposal
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
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;
    yesCount: Int as uint32;
    noCount: Int as uint32;
    voters: map<Address, Bool>; // Map of voter addresses to their votes (true = "yes", false = "no")

    init(data: Init) {
        self.proposalId = data.proposalId;
        self.votingEndingAt = data.votingEndingAt;
        self.yesCount = 0;
        self.noCount = 0;
        self.voters = emptyMap();
    }

    receive() { }

    receive(msg: Vote) {
        // Check if voting period has ended
        if (now() >= self.votingEndingAt) {
            throw(100); // Voting has ended
        }

        let senderAddr: Address = sender();
        
        // Check if sender has already voted
        if (self.voters.get(senderAddr) != null) {
            throw(102); // Already voted
        }
        
        // Record the vote
        self.voters.set(senderAddr, msg.value);
        
        // Update counts
        if (msg.value) {
            self.yesCount = self.yesCount + 1;
        } else {
            self.noCount = self.noCount + 1;
        }
    }

    get fun proposalState(): ProposalState {
        return ProposalState{
            yesCount: self.yesCount,
            noCount: self.noCount
        };
    }
}