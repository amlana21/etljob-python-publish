import pandas as pd


def processData(df_1,df_2):
    print('processing')
    print('inside loop')
    df1=df_1.copy()
    df1.drop([0], inplace=True)
    df2=df_2.copy()
    df2 = df2[df2['Country/Region'] == 'US']
    df3 = df2[['Date', 'Recovered']].copy()
    df3['Recovered'] = df3['Recovered'].values.astype(int)
    df3 = df3.rename(columns={'Date': 'date'})
    df3.set_index('date', inplace=True)
    merge1 = df1.copy()
    merge2 = df3.copy()
    merge1 = merge1.reset_index()
    merge2 = merge2.reset_index()
    merged_df = pd.merge(merge1, merge2)
    merged_df.set_index('date', inplace=True)
    return merged_df
