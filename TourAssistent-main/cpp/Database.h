#ifndef DATABASE_H
#define DATABASE_H

#include <QSqlDatabase>

class Database {
public:
    static void init();
    static QSqlDatabase get();

private:
    static QSqlDatabase db;
};

#endif // DATABASE_H
