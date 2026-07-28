#pragma once
#include <QSqlDatabase>

class Database {
public:
    static void init();
    static QSqlDatabase get();

private:
    static QSqlDatabase db;
};
