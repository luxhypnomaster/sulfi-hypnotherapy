package com.tekartik.sqflite;

import java.util.LinkedList;
import java.util.ListIterator;
import java.util.Objects;

/** Internal SQL scheduling only; not a transfer queue or persistent data. */
final class TransactionScheduler {
    private final LinkedList<DatabaseTask> waiting = new LinkedList<>();
    private Integer owner;
    void offer(DatabaseTask task) { waiting.add(task); }
    DatabaseTask next() {
        ListIterator<DatabaseTask> cursor = waiting.listIterator();
        while (cursor.hasNext()) {
            DatabaseTask task = cursor.next();
            if (owner == null || Objects.equals(owner, task.getDatabaseId())) {
                cursor.remove();
                return task;
            }
        }
        return null;
    }
    void completed(DatabaseTask task) {
        Integer id = task.getDatabaseId();
        if (task.isInTransaction()) {
            if (id == null) throw new IllegalStateException("Transaction without database identity");
            owner = id;
        } else if (Objects.equals(owner, id)) {
            owner = null;
        }
    }
}
