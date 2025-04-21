struct ProposalInit {
    master: Address;
    proposalId: Int as uint32;
}

message DeployNewProposal {
    votingEndingAt: Int as uint32;
}

contract ProposalMaster {
    // State variable to track the next proposal ID
    nextProposalId: Int as uint32;
    
    // Initialize the contract
    init() {
        // Initialize nextProposalId to 0
        self.nextProposalId = 0;
    }
    
    // deploy
    receive() { }

    receive(msg: DeployNewProposal) {
        // Check if the voting end time is in the future
        let currentTime: Int = now();
        require(currentTime < msg.votingEndingAt, "Voting end time must be in the future");
        
        // Deploy a new Proposal contract
        let proposalInit: ProposalInit = ProposalInit{
            master: myAddress(),
            proposalId: self.nextProposalId
        };
        
        // Deploy the new proposal contract
        deploy(DeployParameters{
            value: 0,
            mode: SendRemainingValue,
            bounce: true,
            body: beginCell().storeUint(msg.votingEndingAt, 32).endCell(),
            init: initOf Proposal(proposalInit)
        });
        
        // Increment the next proposal ID
        self.nextProposalId += 1;
    }

    get fun nextProposalId(): Int {
        return self.nextProposalId;
    }
}

// ==============================================================================

message Vote {
    value: Bool;
}

struct ProposalState {
    yesCount: Int as uint32;
    noCount: Int as uint32;
    master: Address;
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;
}

contract Proposal {
    // State variables
    yesCount: Int as uint32;
    noCount: Int as uint32;
    master: Address;
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;
    // Use a simple counter to track the number of votes
    voteCount: Int as uint32;
    voters: map<Address, Bool>;

    init(data: ProposalInit) {
        // Initialize state variables
        self.yesCount = 0;
        self.noCount = 0;
        self.master = data.master;
        self.proposalId = data.proposalId;
        self.votingEndingAt = 0; // Default value
        self.voteCount = 0;
        self.voters = emptyMap();
    }

    receive(msg: Slice) {
        // Set the voting end time from the message
        self.votingEndingAt = msg.loadUint(32);
    }

    receive(msg: Vote) {
        // Check if voting is still open
        let currentTime: Int = now();
        require(currentTime < self.votingEndingAt, "Voting has ended");
        
        // Check if we've reached the maximum number of votes
        require(self.voteCount < 100, "Maximum number of votes reached");

        // Check if voter has already voted
        let voter: Address = sender();
        require(self.voters.get(voter) == null, "Already voted");
        
        // Record the vote
        self.voters.set(voter, true);
        
        // Increment the vote count
        self.voteCount += 1;
        
        // Increment the appropriate counter
        if (msg.value) {
            self.yesCount += 1;
        } else {
            self.noCount += 1;
        }
    }

    get fun proposalState(): ProposalState {
        let state: ProposalState = ProposalState{
            yesCount: self.yesCount,
            noCount: self.noCount,
            master: self.master,
            proposalId: self.proposalId,
            votingEndingAt: self.votingEndingAt
        };
        return state;
    }
}
