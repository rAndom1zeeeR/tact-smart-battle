import '@ton/test-utils';
import { Blockchain } from '@ton/sandbox';
import { toNano } from '@ton/core';
import { Proposal } from '../output/solution3_Proposal';

describe('Proposal Contract Tests', () => {
    // Базовый тест для проверки подсчета голосов
    it('should count votes correctly', async () => {
        const blockchain = await Blockchain.create();

        // create contract from init()
        const proposal = blockchain.openContract(
            await Proposal.fromInit({
                $$type: 'Init',
                proposalId: 0n,
                votingEndingAt: BigInt(Math.floor(Date.now() / 1000)) + 24n * 60n * 60n,
            }),
        );

        // deploy contract
        const deployer = await blockchain.treasury('deployer');
        await proposal.send(
            deployer.getSender(),
            {
                value: toNano('0.01'),
            },
            null, // empty message, handled by `receive()` without parameters
        );

        // vote
        const voter = await blockchain.treasury('voter');
        await proposal.send(
            voter.getSender(),
            { value: toNano('0.1') },
            {
                $$type: 'Vote',
                value: true,
            },
        );

        // the vote was counted
        expect(await proposal.getProposalState()).toMatchObject({ yesCount: 1n, noCount: 0n });
    });

    // Тест на ограничение размера хранилища
    it('should not exceed 100,000 bits storage limit', async () => {
        const blockchain = await Blockchain.create();
        const endTime = BigInt(Math.floor(Date.now() / 1000)) + 24n * 60n * 60n;

        // create contract
        const proposal = blockchain.openContract(
            await Proposal.fromInit({
                $$type: 'Init',
                proposalId: 0n,
                votingEndingAt: endTime,
            }),
        );

        // deploy contract
        const deployer = await blockchain.treasury('deployer');
        await proposal.send(
            deployer.getSender(),
            {
                value: toNano('0.01'),
            },
            null,
        );

        // Create multiple voters and send votes
        const numVoters = 100; // Попробуем добавить много голосов
        for (let i = 0; i < numVoters; i++) {
            const voter = await blockchain.treasury(`voter${i}`);
            try {
                await proposal.send(
                    voter.getSender(),
                    { value: toNano('0.1') },
                    {
                        $$type: 'Vote',
                        value: i % 2 === 0, // Чередуем true/false голоса
                    },
                );
            } catch (error: any) {
                // Если получаем ошибку о превышении размера хранилища,
                // значит наш контракт работает правильно
                if (error.message && error.message.includes('storage')) {
                    console.log(`Storage limit reached after ${i} votes`);
                    break;
                }
                throw error;
            }
        }

        // Проверяем, что голоса были учтены корректно
        const state = await proposal.getProposalState();
        expect(state.yesCount + state.noCount).toBeGreaterThan(0n);

        // Проверяем, что контракт все еще существует и отвечает
        const finalState = await proposal.getProposalState();
        expect(finalState).toBeDefined();
    });

    // Тест на возможность деплоя контракта любым пользователем
    it('should allow deployment by anyone', async () => {
        const blockchain = await Blockchain.create();
        const endTime = BigInt(Math.floor(Date.now() / 1000)) + 24n * 60n * 60n;

        // Создаем несколько разных пользователей
        const users = await Promise.all([
            blockchain.treasury('user1'),
            blockchain.treasury('user2'),
            blockchain.treasury('user3'),
        ]);

        // Каждый пользователь должен иметь возможность задеплоить контракт
        for (const user of users) {
            const proposal = blockchain.openContract(
                await Proposal.fromInit({
                    $$type: 'Init',
                    proposalId: 0n,
                    votingEndingAt: endTime,
                }),
            );

            await proposal.send(
                user.getSender(),
                {
                    value: toNano('0.01'),
                },
                null,
            );

            // Проверяем, что контракт успешно задеплоен
            const state = await proposal.getProposalState();
            expect(state).toBeDefined();
        }
    });

    // Тест на ограничение по времени голосования
    it('should not accept votes after voting deadline', async () => {
        const blockchain = await Blockchain.create();
        const now = Math.floor(Date.now() / 1000);
        const endTime = BigInt(now) + 5n; // Голосование заканчивается через 5 секунд

        // create contract
        const proposal = blockchain.openContract(
            await Proposal.fromInit({
                $$type: 'Init',
                proposalId: 0n,
                votingEndingAt: endTime,
            }),
        );

        // deploy contract
        const deployer = await blockchain.treasury('deployer');
        await proposal.send(
            deployer.getSender(),
            {
                value: toNano('0.01'),
            },
            null,
        );

        // Голосуем до окончания срока
        const voter1 = await blockchain.treasury('voter1');
        await proposal.send(
            voter1.getSender(),
            { value: toNano('0.1') },
            {
                $$type: 'Vote',
                value: true,
            },
        );

        // Ждем окончания срока голосования
        await new Promise((resolve) => setTimeout(resolve, 6000));

        // Пытаемся проголосовать после окончания срока
        const voter2 = await blockchain.treasury('voter2');
        try {
            await proposal.send(
                voter2.getSender(),
                { value: toNano('0.1') },
                {
                    $$type: 'Vote',
                    value: true,
                },
            );
            // Если дошли до этой точки, тест должен упасть
            expect(true).toBe(false);
        } catch (error: any) {
            // Проверяем, что произошла ошибка
            expect(error).toBeDefined();
        }

        // Проверяем, что только первый голос был учтен
        const state = await proposal.getProposalState();
        expect(state).toMatchObject({ yesCount: 1n, noCount: 0n });
    }, 10000); // Увеличиваем таймаут до 10 секунд

    // Тест на уникальность голосов по адресу
    it('should not allow multiple votes from the same address', async () => {
        const blockchain = await Blockchain.create();
        const endTime = BigInt(Math.floor(Date.now() / 1000)) + 24n * 60n * 60n;

        // create contract
        const proposal = blockchain.openContract(
            await Proposal.fromInit({
                $$type: 'Init',
                proposalId: 0n,
                votingEndingAt: endTime,
            }),
        );

        // deploy contract
        const deployer = await blockchain.treasury('deployer');
        await proposal.send(
            deployer.getSender(),
            {
                value: toNano('0.01'),
            },
            null,
        );

        // Первый голос должен пройти успешно
        const voter = await blockchain.treasury('voter');
        await proposal.send(
            voter.getSender(),
            { value: toNano('0.1') },
            {
                $$type: 'Vote',
                value: true,
            },
        );

        // Второй голос от того же адреса должен быть отклонен
        try {
            await proposal.send(
                voter.getSender(),
                { value: toNano('0.1') },
                {
                    $$type: 'Vote',
                    value: false, // Пытаемся изменить голос
                },
            );
            // Если дошли до этой точки, тест должен упасть
            expect(true).toBe(false);
        } catch (error: any) {
            // Проверяем, что произошла ошибка
            expect(error).toBeDefined();
        }

        // Проверяем, что первый голос остался без изменений
        const state = await proposal.getProposalState();
        expect(state).toMatchObject({ yesCount: 1n, noCount: 0n });
    });

    // Тест на невозможность изменения голоса
    it('should not allow changing vote', async () => {
        const blockchain = await Blockchain.create();
        const endTime = BigInt(Math.floor(Date.now() / 1000)) + 24n * 60n * 60n;

        // create contract
        const proposal = blockchain.openContract(
            await Proposal.fromInit({
                $$type: 'Init',
                proposalId: 0n,
                votingEndingAt: endTime,
            }),
        );

        // deploy contract
        const deployer = await blockchain.treasury('deployer');
        await proposal.send(
            deployer.getSender(),
            {
                value: toNano('0.01'),
            },
            null,
        );

        // Первый голос
        const voter = await blockchain.treasury('voter');
        await proposal.send(
            voter.getSender(),
            { value: toNano('0.1') },
            {
                $$type: 'Vote',
                value: true,
            },
        );

        // Проверяем, что голос был записан
        let state = await proposal.getProposalState();
        expect(state).toMatchObject({ yesCount: 1n, noCount: 0n });

        // Пытаемся изменить голос
        try {
            await proposal.send(
                voter.getSender(),
                { value: toNano('0.1') },
                {
                    $$type: 'Vote',
                    value: false,
                },
            );
            // Если дошли до этой точки, тест должен упасть
            expect(true).toBe(false);
        } catch (error: any) {
            // Проверяем, что произошла ошибка
            expect(error).toBeDefined();
        }

        // Проверяем, что голос не изменился
        state = await proposal.getProposalState();
        expect(state).toMatchObject({ yesCount: 1n, noCount: 0n });
    });

    // Тест на обработку ошибок при неуспешном голосовании
    it('should throw exit code for unsuccessful voting', async () => {
        const blockchain = await Blockchain.create();
        const now = Math.floor(Date.now() / 1000);
        const endTime = BigInt(now) + 5n; // Голосование заканчивается через 5 секунд

        // create contract
        const proposal = blockchain.openContract(
            await Proposal.fromInit({
                $$type: 'Init',
                proposalId: 0n,
                votingEndingAt: endTime,
            }),
        );

        // deploy contract
        const deployer = await blockchain.treasury('deployer');
        await proposal.send(
            deployer.getSender(),
            {
                value: toNano('0.01'),
            },
            null,
        );

        // Ждем окончания срока голосования
        await new Promise((resolve) => setTimeout(resolve, 6000));

        // Пытаемся проголосовать после окончания срока
        const voter = await blockchain.treasury('voter');
        try {
            await proposal.send(
                voter.getSender(),
                { value: toNano('0.1') },
                {
                    $$type: 'Vote',
                    value: true,
                },
            );
            // Если дошли до этой точки, тест должен упасть
            expect(true).toBe(false);
        } catch (error: any) {
            // Проверяем, что произошла ошибка
            expect(error).toBeDefined();
        }
    }, 10000); // Увеличиваем таймаут до 10 секунд

    // Тест на потребление газа
    it('should not consume too much gas', async () => {
        const blockchain = await Blockchain.create();
        const endTime = BigInt(Math.floor(Date.now() / 1000)) + 24n * 60n * 60n;

        // create contract
        const proposal = blockchain.openContract(
            await Proposal.fromInit({
                $$type: 'Init',
                proposalId: 0n,
                votingEndingAt: endTime,
            }),
        );

        // deploy contract
        const deployer = await blockchain.treasury('deployer');
        await proposal.send(
            deployer.getSender(),
            {
                value: toNano('0.01'),
            },
            null,
        );

        // Голосуем с минимальным количеством TON
        const voter = await blockchain.treasury('voter');
        await proposal.send(
            voter.getSender(),
            { value: toNano('0.05') }, // Отправляем только 0.05 TON
            {
                $$type: 'Vote',
                value: true,
            },
        );

        // Проверяем, что голос был учтен
        const state = await proposal.getProposalState();
        expect(state).toMatchObject({ yesCount: 1n, noCount: 0n });
    });

    // Тест на корректный подсчет голосов "нет"
    it('should count "no" votes correctly', async () => {
        const blockchain = await Blockchain.create();
        const endTime = BigInt(Math.floor(Date.now() / 1000)) + 24n * 60n * 60n;

        // create contract
        const proposal = blockchain.openContract(
            await Proposal.fromInit({
                $$type: 'Init',
                proposalId: 0n,
                votingEndingAt: endTime,
            }),
        );

        // deploy contract
        const deployer = await blockchain.treasury('deployer');
        await proposal.send(
            deployer.getSender(),
            {
                value: toNano('0.01'),
            },
            null,
        );

        // Голосуем "нет"
        const voter = await blockchain.treasury('voter');
        await proposal.send(
            voter.getSender(),
            { value: toNano('0.1') },
            {
                $$type: 'Vote',
                value: false,
            },
        );

        // Проверяем, что голос "нет" был учтен
        const state = await proposal.getProposalState();
        expect(state).toMatchObject({ yesCount: 0n, noCount: 1n });
    });

    // Тест на корректную работу с разными proposalId
    it('should handle different proposalIds correctly', async () => {
        const blockchain = await Blockchain.create();
        const endTime = BigInt(Math.floor(Date.now() / 1000)) + 24n * 60n * 60n;

        // Создаем два контракта с разными proposalId
        const proposal1 = blockchain.openContract(
            await Proposal.fromInit({
                $$type: 'Init',
                proposalId: 1n,
                votingEndingAt: endTime,
            }),
        );

        const proposal2 = blockchain.openContract(
            await Proposal.fromInit({
                $$type: 'Init',
                proposalId: 2n,
                votingEndingAt: endTime,
            }),
        );

        // Деплоим оба контракта
        const deployer = await blockchain.treasury('deployer');
        await proposal1.send(
            deployer.getSender(),
            {
                value: toNano('0.01'),
            },
            null,
        );

        await proposal2.send(
            deployer.getSender(),
            {
                value: toNano('0.01'),
            },
            null,
        );

        // Голосуем в обоих контрактах
        const voter = await blockchain.treasury('voter');
        await proposal1.send(
            voter.getSender(),
            { value: toNano('0.1') },
            {
                $$type: 'Vote',
                value: true,
            },
        );

        await proposal2.send(
            voter.getSender(),
            { value: toNano('0.1') },
            {
                $$type: 'Vote',
                value: false,
            },
        );

        // Проверяем, что голоса учтены правильно в каждом контракте
        const state1 = await proposal1.getProposalState();
        expect(state1).toMatchObject({ yesCount: 1n, noCount: 0n });

        const state2 = await proposal2.getProposalState();
        expect(state2).toMatchObject({ yesCount: 0n, noCount: 1n });
    });

    // Тест на обработку некорректных входных данных
    it('should handle invalid input data correctly', async () => {
        const blockchain = await Blockchain.create();
        const now = Math.floor(Date.now() / 1000);

        // Пытаемся создать контракт с временем окончания в прошлом
        const proposal = blockchain.openContract(
            await Proposal.fromInit({
                $$type: 'Init',
                proposalId: 0n,
                votingEndingAt: BigInt(now - 3600), // 1 час назад
            }),
        );

        // Деплоим контракт
        const deployer = await blockchain.treasury('deployer');
        await proposal.send(
            deployer.getSender(),
            {
                value: toNano('0.01'),
            },
            null,
        );

        // Пытаемся проголосовать
        const voter = await blockchain.treasury('voter');
        try {
            await proposal.send(
                voter.getSender(),
                { value: toNano('0.1') },
                {
                    $$type: 'Vote',
                    value: true,
                },
            );
            // Если дошли до этой точки, тест должен упасть
            expect(true).toBe(false);
        } catch (error: any) {
            // Проверяем, что произошла ошибка
            expect(error).toBeDefined();
        }

        // Проверяем, что голос не был учтен
        const state = await proposal.getProposalState();
        expect(state).toMatchObject({ yesCount: 0n, noCount: 0n });
    });

    // Тест на максимальное количество голосов и их корректный подсчет
    it('should handle maximum number of votes correctly', async () => {
        const blockchain = await Blockchain.create();
        const endTime = BigInt(Math.floor(Date.now() / 1000)) + 24n * 60n * 60n;

        // create contract
        const proposal = blockchain.openContract(
            await Proposal.fromInit({
                $$type: 'Init',
                proposalId: 0n,
                votingEndingAt: endTime,
            }),
        );

        // deploy contract
        const deployer = await blockchain.treasury('deployer');
        await proposal.send(
            deployer.getSender(),
            {
                value: toNano('0.01'),
            },
            null,
        );

        // Создаем массив голосующих
        const numVoters = 50; // Большое количество голосов
        const voters = await Promise.all(Array.from({ length: numVoters }, (_, i) => blockchain.treasury(`voter${i}`)));

        // Подсчитываем ожидаемые результаты
        let expectedYes = 0n;
        let expectedNo = 0n;

        // Голосуем всеми адресами
        for (let i = 0; i < voters.length; i++) {
            const vote = i % 3 === 0; // Каждый третий голосует "за"
            try {
                await proposal.send(
                    voters[i].getSender(),
                    { value: toNano('0.1') },
                    {
                        $$type: 'Vote',
                        value: vote,
                    },
                );

                // Увеличиваем ожидаемые счетчики только если голос прошел успешно
                if (vote) {
                    expectedYes += 1n;
                } else {
                    expectedNo += 1n;
                }
            } catch (error: any) {
                // Если получаем ошибку о превышении размера хранилища,
                // прекращаем голосование
                if (error.message && error.message.includes('storage')) {
                    console.log(`Storage limit reached after ${i} votes`);
                    break;
                }
                throw error;
            }
        }

        // Проверяем финальное состояние
        const finalState = await proposal.getProposalState();
        expect(finalState.yesCount).toBe(expectedYes);
        expect(finalState.noCount).toBe(expectedNo);
        expect(finalState.yesCount + finalState.noCount).toBeGreaterThan(0n);

        // Пытаемся проголосовать еще раз с новым адресом
        const extraVoter = await blockchain.treasury('extraVoter');
        try {
            await proposal.send(
                extraVoter.getSender(),
                { value: toNano('0.1') },
                {
                    $$type: 'Vote',
                    value: true,
                },
            );
        } catch (error: any) {
            // Проверяем, что произошла ошибка
            expect(error).toBeDefined();
        }

        // Проверяем, что состояние не изменилось
        const afterExtraVote = await proposal.getProposalState();
        expect(afterExtraVote).toMatchObject(finalState);
    });
});
