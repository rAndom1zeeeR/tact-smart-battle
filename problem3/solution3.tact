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
    // Устанавливаем резерв для хранения в 0.0125 TON (100 000 бит)
    override const storageReserve: Int = ton("0.0125");
    
    // State variables
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;
    yesCount: Int as uint32;
    noCount: Int as uint32;
    // Храним хеши адресов для экономии места
    voters: map<Int as uint256, Bool>; // Map of address hashes to their votes (true = "yes", false = "no")
    
    // Contract initialization
    init(data: Init) {
        self.proposalId = data.proposalId;
        self.votingEndingAt = data.votingEndingAt;
        self.yesCount = 0;
        self.noCount = 0;
        self.voters = emptyMap();
    }

    // Empty handler for deployment
    receive() { }

    // Message handler for voting
    receive(msg: Vote) {
        // Check if voting is still open
        require(now() < self.votingEndingAt, "Voting has ended");
        
        // Get sender address and compute its hash
        let sender = sender();
        let senderSlice = sender.asSlice();
        let senderHash = senderSlice.hash();
        
        // Check if voter has already voted
        require(self.voters.get(senderHash) == null, "Already voted");
        
        // Проверяем размер сообщения и вычисляем комиссию
        let fwdFee: Int = getForwardFee(1, 256 + 1, false); // 256 bits for hash + 1 bit for bool
        require(myBalance() >= fwdFee + ton("0.01"), "Insufficient balance for message");
        
        // Проверяем, не достигнуто ли максимальное количество голосов
        let totalVotes = self.yesCount + self.noCount;
        require(totalVotes < 50, "Maximum number of votes reached");
        
        // Записываем голос и увеличиваем счетчики только если запись прошла успешно
        self.voters.set(senderHash, msg.value);
        
        // Увеличиваем счетчики после успешной записи голоса
        if (msg.value) {
            self.yesCount = self.yesCount + 1;
        } else {
            self.noCount = self.noCount + 1;
        }
        
        // Reimburse excess funds
        let excess = myBalance() - ton("0.01"); // 0.01 TON for gas
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
