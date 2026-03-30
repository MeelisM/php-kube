<?php

declare(strict_types=1);

final class ItemRepository
{
    public function __construct(private PDO $pdo)
    {
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    public function all(): array
    {
        $statement = $this->pdo->query('SELECT id, name, created_at FROM items ORDER BY id ASC');

        return $statement->fetchAll();
    }

    /**
     * @return array<string, mixed>
     */
    public function create(string $name): array
    {
        $statement = $this->pdo->prepare('INSERT INTO items (name) VALUES (:name)');
        $statement->execute(['name' => $name]);

        $id = (int) $this->pdo->lastInsertId();

        $select = $this->pdo->prepare('SELECT id, name, created_at FROM items WHERE id = :id');
        $select->execute(['id' => $id]);

        $item = $select->fetch();

        if ($item === false) {
            throw new RuntimeException('Created item could not be retrieved.');
        }

        return $item;
    }
}
