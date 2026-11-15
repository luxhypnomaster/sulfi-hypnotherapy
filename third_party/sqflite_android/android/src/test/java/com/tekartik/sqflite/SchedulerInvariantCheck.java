package com.tekartik.sqflite;

/** Pure scheduling invariants; separate from real Android SQLite evidence. */
public final class SchedulerInvariantCheck {
  static final class Db implements DatabaseDelegate {
    final int id; boolean tx;
    Db(int id) { this.id=id; }
    public int getDatabaseId() { return id; }
    public boolean isInTransaction() { return tx; }
  }
  static DatabaseTask task(Db db) { return new DatabaseTask(db, () -> {}); }
  static void same(Object a, Object b) { if (a!=b) throw new AssertionError("SCHEDULING_ORDER_CHANGED"); }
  static void active(TransactionScheduler s, Db db) {
    DatabaseTask begin=task(db);s.offer(begin);same(s.next(),begin);db.tx=true;s.completed(begin);
  }
  public static void main(String[] args) {
    Db a=new Db(1),b=new Db(2);
    TransactionScheduler s=new TransactionScheduler();
    DatabaseTask one=task(a),two=task(b);
    s.offer(one);s.offer(two);same(s.next(),one);s.completed(one);same(s.next(),two);s.completed(two);same(s.next(),null);
    System.out.println("SCHEDULER_INVARIANT=FIFO_WITHOUT_TRANSACTION:PASS");
    s=new TransactionScheduler();active(s,a);
    DatabaseTask foreign=task(b),commit=task(a);
    s.offer(foreign);same(s.next(),null);s.offer(commit);same(s.next(),commit);
    a.tx=false;s.completed(commit);same(s.next(),foreign);s.completed(foreign);
    System.out.println("SCHEDULER_INVARIANT=FOREIGN_DEFERRED_OWNER_COMMIT_MAKES_PROGRESS:PASS");
    s=new TransactionScheduler();active(s,a);
    DatabaseTask global=new DatabaseTask(null,()->{}),continuation=task(a);
    s.offer(global);s.offer(foreign);same(s.next(),null);s.offer(continuation);same(s.next(),continuation);s.completed(continuation);same(s.next(),null);
    s.offer(commit);same(s.next(),commit);a.tx=false;s.completed(commit);same(s.next(),global);s.completed(global);same(s.next(),foreign);s.completed(foreign);
    System.out.println("SCHEDULER_INVARIANT=UNKNOWN_GLOBAL_WORK_CANNOT_BLOCK_OWNER:PASS");
    s=new TransactionScheduler();active(s,a);s.offer(continuation);same(s.next(),continuation);s.completed(continuation);
    s.offer(foreign);same(s.next(),null);s.offer(commit);same(s.next(),commit);a.tx=false;s.completed(commit);same(s.next(),foreign);s.completed(foreign);
    System.out.println("SCHEDULER_INVARIANT=NESTED_TRANSACTION_NOT_PREMATURELY_RELEASED:PASS");
    s=new TransactionScheduler();active(s,a);s.offer(foreign);s.offer(commit);same(s.next(),commit);a.tx=false;s.completed(commit);
    same(s.next(),foreign);b.tx=true;s.completed(foreign);s.offer(one);same(s.next(),null);
    DatabaseTask bcommit=task(b);s.offer(bcommit);same(s.next(),bcommit);b.tx=false;s.completed(bcommit);same(s.next(),one);s.completed(one);same(s.next(),null);
    System.out.println("SCHEDULER_INVARIANT=OWNERSHIP_TRANSFERS_ONLY_AFTER_COMMIT:PASS");
  }
}
