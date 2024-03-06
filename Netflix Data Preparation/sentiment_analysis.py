from textblob import TextBlob
import pandas as pd

# Read the csv into a dataframe
df = pd.read_csv('ta.csv')

# Function to use TextBlob to get the sentiment
def get_sentiment(text):
    blob = TextBlob(text)
    return blob.sentiment.polarity, blob.sentiment.subjectivity

# Apply the get_sentiment function to each description
df[['Polarity', 'Subjectivity']] = df['description'].apply(
    lambda x: pd.Series(get_sentiment(x))
)

# Save to CSV
df.to_csv('sentiment_analysis.csv', columns=['title', 'description', 'Polarity', 'Subjectivity'], index=False)
